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
- **Soft-launch öncesi monetizasyon planı (owner kararı, M8.9):** ödüllü
  devam (revive) + ödüllü güç refill'i + banner (Ana Sayfa / Harita / Mağaza /
  Koleksiyon / oyun) + **geçiş reklamı** (15 dk aktif süre, yalnız round
  bitişi molasında, 60 sn tam ekran beklemesi) + **günlük ödüller** (ücretsiz
  sandık 1/gün, reklamlı sandık 2/gün, reklamlı +150 Hamur 1/gün, otomatik
  GÜNLÜK ÖDÜLLER penceresi + Mağaza kartı) **v1'DE VAR** — Google AdMob,
  `M8.9-01` temeli A36'da doğrulanıp main'e alındı, `M8.9-02` genişletmesi test
  reklamıyla entegre edildi (docs/monetization/ADS_SYSTEM.md,
  DAILY_REWARDS.md). Üretim kimlikleri (3 birim) ve AdMob hesabı kurulumu ayrı
  adım. **App-open / rewarded interstitial / mediation YOK.**
- Gerçek para **Güç Paketi** planlanıyor ama **HENÜZ KURULMADI** — Play
  Billing yok, fiyat/product ID yok. Skinler hiçbir zaman gerçek parayla
  satılmayacak. Bkz. GAME_DESIGN §5.7.
- v1'de **oyun içi mağaza VAR**: Hamur ile kozmetik skin satın alınıyor.
  Gerçek para geçmiyor — soft-currency sink'i, IAP değil. Bkz. GAME_DESIGN §5.6.
- Ticari/growth kararları (interstitial dahil) gerçek veriyle alınacak.

## Success metric
v1 için "başarı" = Play Console kapalı test track'inde canlı, crash'siz, tam
oynanabilir bir build. Ticari/growth kararları v1.1'de gerçek veriyle
alınacak — şimdi tahmin/vaat yok.

## Non-goals (v1 — bilinçli olarak YAPILMIYOR)
- Çoklu kavanoz/tema seçeneği (tek sabit tema)
- IAP / Play Billing **kurulumu** (tasarımı yapıldı, kod YOK — GAME_DESIGN
  §5.7.4). ~~Reklam~~ → **M8.9'da v1'e alındı** (ödüllü devam + ödüllü
  refill + günlük ödüllü sandık/Hamur + banner + geçiş reklamı, AdMob);
  **rewarded interstitial / app-open / mediation / analitik SDK non-goal**
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
  sandık/koleksiyon/mağaza, günlük ödül, Home hub + `ScreenTopBar` gezinmesi
  (M8.5'in 4 sekmeli alt çubuğu M8.6-06'da kalktı), owner'ın görsel
  asset'leri entegre.
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
  - `M8.6-03B` ✅ production Home **hub** (dal `task/021-home-hub-redesign`,
    A36 cihaz kapısı geçti, main 6f9db44): rakip referansın hub mimarisi, Squishy
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
    yok). **03B.1 final polish (2026-09-16):** ayarlar butonu "oturmadı"
    → kök neden HUD v5 köşe reçetesinin pişmiş gölge/halka kayıt hatası
    (UI_VISUAL_SYSTEM §14.5), Home'a düz plakalı `home_icon_button`; üst
    pill'ler koyu cipten HUD v5 lavanta glossy `home_pill`'e (56 px tek
    satır, ortak merkez); level plakası → OYNA'ya bağlı lavanta pill + altın
    taç madalyonu; uzun ekranda sütunlar hero yanına yayılır, OYNA yukarı,
    bantta pırıltılar; yeni oyuncuda "Seri başlasın"; HUD "SIRADAKİ".
    **03B.2:** OYNA altta ORTADA ve büyük (480×96), hemen üstünde ortalanmış
    kompakt level pill'i (owner: yan yana düzen OYNA'yı ikincil gösteriyordu).
    `tools/home_ui_test` 207/207 (6 pencere + A36), ui_foundation 147/147,
    ui_smoke 72, shell 147; `tools/home_shots` 10 durum × 4 boyut + A36
    simülasyonu (build/qa_m8.6-03b-final/, play_cta/). **Ekonomi, ilerleme, günlük ödül kuralı,
    kayıt şeması, gameplay HUD v5 yerleşimi DEĞİŞMEDİ** (HUD'da yalnız
    "SIRADAKİ" yazımı). **A36 cihaz kapısı geçti, owner onayladı, main'e
    alındı (6f9db44).** Ayrıntı: UI_VISUAL_SYSTEM §14.
  - `M8.6-04` ✅ production **journey map** (dal `task/022-map-production-ui`,
    A36 cihaz kapısı geçti, owner onayladı, main'e alındı af3af5c): Home'daki OYNA'nın ilk durağı, owner'ın
    candy dünyası kahraman. Üst satır `ScreenTopBar` (yeniden kullanılabilir:
    oturmuş geri → Ana Sayfa · pembe "HARİTA" kurdelesi · Hamur pill'i + nane
    "+" → Mağaza); sekme çubuğu Harita'da da GİZLİ (`_tabs.visible = tab >= 2`),
    dünya tabana kadar. Eski tam ekran karartma yerine kenar vignette + üst
    haze; punch-hole'da dünya güvenli payın altından başlar (bant = zeminin
    üst satırları). On level + Sonsuz tek bileşenden (`MapLevelNode`, 5 durum:
    tamamlanmış cyan + yıldız / sıradaki ×1.14 altın halka + nefes alan hale +
    "OYNA" plakası / kilitli lavanta + owner kilit, dokununca sallanır ve
    ASLA başlamaz / Sonsuz açık altın taç madalyonu + "Rekor N" / Sonsuz
    kilitli + "Level 10'u bitir"); perspektif çap 84→72, uzun ekranda büyür;
    patika 10 px candy + erik gölge + inci noktalar (tamamlanmış şeftali-altın).
    Konumlar 2/4/5 yola alındı, 8/9/10 aralığı açıldı. `tools/map_ui_test`
    127/127 (4 pencere + A36), `tools/map_shots` 10 durum × 4 boyut + A36;
    ui_foundation 154/154 (+4 variation), home_ui 207/207 (çubuk Harita'da
    gizli), ui_smoke 72, shell 147, skin 30, audio 45, economy 100, refill 119,
    revive 120, bot L3 2/2 (build/qa_m8.6-04/). **Level verisi, unlock/yıldız
    kuralı, Sonsuz şartı, level başlatma yolu, ekonomi, kayıt şeması, fizik,
    Home, gameplay DEĞİŞMEDİ.** **A36 cihaz kapısı geçti (75f0e49):** tek
    kusur — punch-hole bandı dikişi — `flip_v` ile kapatıldı; rotalar,
    kilitli/sıradaki/tamamlanmış/Sonsuz durumları, açılış animasyonu ve
    logcat cihazda temiz (build/qa_m8.6-04/device/). Ayrıntı: UI_VISUAL_SYSTEM §15.
  - `M8.6-05` 🔶 production **Mağaza** (PRE-DEVICE VISUAL REVIEW, dal
    `task/023-shop-production-ui`, main af3af5c üzerine): eski koyu satır
    listesi / neon pill / alt sekme çubuğu kalktı; dikey casual-game dükkânı:
    `ScreenTopBar` (geri → Ana Sayfa · pembe "MAĞAZA" · Hamur pill'i **"+"
    YOK** — Mağaza zaten "+"ın hedefi), gerçek ScrollContainer (üst satırın
    altından kayar, düz koyu bant + solma), `UiKit.section_header` plakaları
    (GÜÇLER / SKİNLER), 2 sütun grid (kart 328×372): 4 × `ShopPowerCard`
    (lavanta-krem gövde = HUD güç tepsisi tonu; candy kuyu + vurgu halesi
    içinde owner güç sanatı 88 px, ad, gerçek mekanik amaç, Hamur fiyatı,
    cyan candy SATIN AL 64 px, altın "Stok ×N" rozeti) + 20 × `ShopSkinCard`
    (krem gövde; canlı `SkinSwatch` önizleme, rarity halkası/hale/pırıltı —
    Common/Rare/Epic/Legendary, Legendary sıcak altın-krem —, rarity etiketi,
    fiyat veya "Koleksiyon'da tak" ipucu + SAHİPSİN (açık nane) / TAKILI
    (nane) plakası). Durumlar: normal / basılı / **Hamur yetmiyor** (soluk
    cyan `CYAN_MUTED` buton, koyu pembe fiyat, dokununca sallanma + kartın
    altında pembe plaka — sessiz değil, bedava para yok) / başarı (pop +
    pırıltı + nane plaka + bakiye). Onay penceresi `UiKit.modal_frame`
    (ürün sunumu + "Bakiye 335 → 215").
    Satın alma yalnız kanonik tek transaction (`PowerUpEconomy.purchase` /
    `Shop.purchase`); Mağaza skin TAKMAZ. Sekme çubuğu artık yalnız
    Koleksiyon'da (`_tabs.visible = tab == 2`). `tools/shop_ui_test` 174/174
    (4 pencere + A36), ui_foundation 162/162 (+7 variation), ui_smoke 72,
    economy 100 (mağaza kontrolleri yeni karta uyarlandı); `tools/shop_shots`
    17 durum × 4 boyut + A36 (build/qa_m8.6-05/). **Fiyatlar (100/120/160/180,
    50/150/400/900), ödüller, kayıt şeması, skin equip kuralı, gameplay, Home,
    Harita DEĞİŞMEDİ.** Sahte monetizasyon YOK. **Telefon/ADB kullanılmadı;
    owner görsel onayı + cihaz kapısı bekliyor.** Ayrıntı: UI_VISUAL_SYSTEM §16.
    **05.1 görsel cila (2026-09-17, aynı dal, PRE-DEVICE):** yeniden tasarım
    değil, tek malzeme/odak pası — skin önizlemesi 164 (+%17), güç sanatı 96
    (+%9), kart 328×384, SATIN AL 60; kart yüzü (`UiKit.card_face`: kırpılmış
    beyaz radyal ışık + `popup_light` gloss bandı, gövde tonu korunur),
    karakterin arkasında rarity renginde düşük-alfa hale, Rare/Epic halkası
    daha okunur, Legendary aynen; stok rozeti kuyunun sağ üst omzuna (gameplay
    madalyonuyla aynı yer); bölüm plakası dudak + parlama; onay sunumu 190,
    X kurdele kuyruğundan ayrıldı ve krem halkayla oturdu (yalnız Mağaza).
    Ekonomi/kayıt/equip/rotalar DEĞİŞMEDİ. `tools/shop_ui_test` 212/212
    (06.3: SATIN AL üstünden sürükleme dizileri); QA `build/qa_m8.6-05.1/`.
    **06.3 (dbf9127, dal task/024):** SATIN AL butonundan başlayan dikey
    sürükleme cihazda 0 px kaydırıyordu (Button varsayılanı STOP →
    ScrollContainer basışı görmüyor) → iki kartın butonu `MOUSE_FILTER_PASS`
    + kaydırma başlayınca basış görseli bırakılır; sürükleme onay açamaz
    (BaseButton basışı iptal eder), temiz dokunuş tek onay. Satın alma yolu,
    fiyat, onay, yerleşim değişmedi; A36'da hedefli yeniden doğrulandı. **A36 cihaz kapısı geçti (6baafbd,
    2026-09-17):** debug APK 45.5 MB sızıntısız, native 1080×2340'ta üst
    satır punch-hole altında, kartlar/rarity/TAKILI okunur, kaydırma ve
    fling kararlı, onay X'i kurdeleye binmiyor; geçici kayıtlarla güç (335→215
    →35, stok 0 → 1 dahil), skin (1500→1350, auto-equip yok) satın alma ve
    Hamur yetmiyor yolu doğrulandı; owner kaydı byte-identical geri kondu;
    logcat 0 SCRIPT ERROR / 0 E godot / 0 FATAL. Cihaza özel kusur YOK.
    Owner manuel onayı + merge izni bekliyor (`build/qa_m8.6-05.1/device/`).
  - `M8.6-06` ✅ production **Koleksiyon** (DEVICE VERIFIED, dal
    `task/024-collection-production-ui`, main 589377b üzerine): eski M8.5-13
    albüm (lacivert plakalar, gri "?" silüet kartlar, 4 sütun, alt sekme
    çubuğu, ~141 px vitrin) kalktı; **premium karakter gardırobu**: sabit
    `ScreenTopBar` (geri → Ana Sayfa · pembe "KOLEKSİYON" · Hamur pill'i +
    nane "+" → Mağaza) → **sabit vitrin** (rarity halesi + candy kaide
    üstünde 296–320 px GERÇEK skin sanatı, nefes alır; ad; Türkçe rarity
    etiketi YAYGIN/NADİR/EPİK/EFSANEVİ + tek durum çipi; tek eylem yuvası:
    cyan **TAK** / **MAĞAZAYA GİT** ya da nane **TAKILI** plakası; KOLEKSİYON
    N/20 pill'i, 20/20 altın) → **kaydırılan galeri** (rarity bölüm plakaları,
    3 sütun ortalı sıralar, `CollectionSkinCard` 216×220 = `MOUSE_FILTER_PASS`
    Button: 20 skin katalog sırasında — **Varsayılan** (06.1, owner onayı
    sonrası) YAYGIN'ın üstünde ayrı 672×116 **ORİJİNAL taban şeridi** (koleksiyon
    skini değil, sayılmaz, fiyatsız; seçilir/takılır), kilitli kart da final
    sanat — buzlu gövde + kilit, fiyat kartta değil vitrinde; takılı kartta
    nane TAKILI, seçili kartta cyan halka). Kart dokunuşu yalnız SEÇER (kayıt
    değişmez); TAK → `SaveManager.equip_skin` (tek yazma); kilitli MAĞAZAYA
    GİT → Mağaza hedef karta kaydırır (`ShopScreen.focus_skin`). Koleksiyon
    satın ALMAZ. Alt sekme çubuğu (`tab_bar.*`) tamamen SİLİNDİ.
    `SkinData.rarity_display_name/upper` (iç ad değişmedi; Mağaza etiketi ve
    onay metni de Türkçe). Tema +2 variation. `tools/collection_ui_test`
    164/164 (4 pencere + A36), ui_smoke 74, shop_ui 199, home_ui 207, map_ui
    127, ui_foundation 164, shell 147, skin 30, audio 45, economy 100, refill
    119, revive 120, bot L3 2/2; `tools/collection_shots` 20 durum × 4 boyut
    + A36 (build/qa_m8.6-06/). **Ekonomi, fiyatlar, sandık, kayıt şeması,
    gameplay, Home, Harita, Mağaza kompozisyonu DEĞİŞMEDİ.** **A36 cihaz
    kapısı geçti (06.2, 2026-09-17):** debug APK 45.6 MB sızıntısız, native
    1080×2340'ta üst satır cutout altında ve kaydırmada 0 px, ORİJİNAL şeridi /
    rarity dili / 3 sütun / TAKILI okunur, karttan-sanattan-şeritten başlayan
    sürüklemeler kaydırır ve seçmez; geçici kayıtlarla seçim (yazma yok), TAK
    (tek yazma: yalnız `equipped_skin`), TAKILI dokunuşu (yazma yok), kilitli →
    MAĞAZAYA GİT (satın alma yok, Mağaza hedef karta kaydı), Varsayılan TAK
    (sayaç 4/20 sabit), 20/20 ödülsüz; owner cihaz kaydı byte-identical geri
    kondu; logcat 0 SCRIPT ERROR / 0 E godot / 0 FATAL / 0 ANR. Tek cihaz
    kusuru: aynı karede basış+bırakış üst satır geri butonunu kalıcı 0.94'te
    bırakıyordu (paylaşılan `UiMotion`) → dar düzeltme `1c82f94`, cihazda
    yeniden doğrulandı. Gözlem (değişmedi): Mağaza SATIN AL'dan başlayan
    sürükleme kaydırmıyor → 06.3 `dbf9127` ile kapatıldı (Mağaza maddesi).
    Push edildi; **merge izni bekliyor** (`build/qa_m8.6-06/device/`).
    Ayrıntı: UI_VISUAL_SYSTEM §17.
  - `M8.6-07` ✅ **ikincil UI denetimi** (dal `task/025-secondary-ui-audit`,
    main 0d248f4 üzerine, yalnız araç + doküman; yeniden tasarım YOK, telefon/ADB
    YOK): kalan yedi runtime yüzeyi (Günlük, Bonus Sandık, Ayarlar, Mola, Round
    sonu, Devam, Refill) + Mağaza onayı (referans) envanterlendi;
    `tools/secondary_ui_shots.tscn` 48 durum × 4 pencere + A36 simülasyonu
    (`build/qa_m8.6-07/`: SECONDARY_UI_INVENTORY / AUDIT / DEPENDENCIES /
    ROADMAP + contact sheet'ler). Bulgu: üç pencere iskeleti (A `modal_frame`
    / B M8.5-08 candy panel + `CandyButton` / C koyu M8.5-10 panel); Ayarlar
    Gizlilik metni sabit çerçeveden taşıyor (shipped kusur); Round sonu
    İngilizce rarity + koyu panel + sınırsız aşağı büyüme; Devam/Refill'de
    birincil-ikincil CTA aynı. Sonuç: 1 production (Mağaza onayı), 2 cila
    (Mola, Bonus Sandık), 5 yeniden kurulum. Sıra: **M8.6-08** shell v2 +
    Ayarlar + Günlük + kapat oturması → **M8.6-09** Round sonu + sandık reveal
    → **M8.6-10** Devam + Refill + M8.5 kalıntılarının emekliliği (her biri
    A36 kapılı). Ayrıntı: UI_VISUAL_SYSTEM §18. ui_foundation 164, ui_smoke 74.
  - `M8.6-08` ✅ **pencere iskeleti v2 + Ayarlar + Günlük + Mola/Bonus
    Sandık cilası** (DEVICE VERIFIED, dal
    `task/026-production-secondary-shell`, denetim 2470231 üzerine):
    `UiKit.modal_shell` (aynı krem gövde/gloss/parıltı malzemesi; kurdele YA
    DA gövde içi Baloo başlık + owner tepeliği; X **her zaman oturmuş** —
    05.1 halkası + gölge, kurdele kuyruğuna binmez; gövde ScrollContainer'da,
    altlık sabit; pencere içeriği kadar büyür, güvenli tavanı aşınca gövde
    kaydırılır, metin küçülmez; `attach_dim_close` tek karartma anlamı =
    bırakışta, emülasyon olayı filtreli; `settings_row` + `settings_divider`),
    `StreakStrip` (7 gerçek düğüm: nane tik / altın odak + yıldız / lavanta,
    "+N" rozeti). **Ayarlar** yeniden kuruldu (tepelik + AYARLAR, 3 satır +
    nane anahtar 96×52 PASS, Gizlilik krem plakada açılır, sürüm + Kapat
    altlıkta) — **shipped taşma kusuru yapısal olarak kapandı** (5 pencere
    yapılandırmasında metin/sürüm/Kapat panelde; regresyon kontrolü). **Günlük**
    yeniden kuruldu (pembe candy kuyuda Hamur + altın pırıltılar, "+15 HAMUR",
    "N. GÜN", seri şeridi, AL kahraman CTA = kutlama → kapanır → Ana Sayfa
    yenilenir; alınmış durum "Bugünkü ödülünü aldın" + TAMAM; karartma
    dokunuşu artık kapatır). Mola/Bonus Sandık: oturmuş X, eylemler altlıkta,
    sandık altın kuyuda. Ayarlar katman 13 + `open_pause_menu` Ayarlar
    açıkken mola açmaz (tek odak). `modal_frame` ve Mağaza onayı DEĞİŞMEDİ
    (10 karede piksel piksel aynı). `tools/secondary_modal_ui_test` 102/102;
    tam kapı: ui_foundation 164, ui_smoke 74, home_ui 207, map_ui 127, shop_ui
    212, collection_ui 164, shell 147, skin 30, audio 45, economy 100, refill
    119, revive 120, bot L3 2/2; owner kaydı byte-identical; `build/qa_m8.6-08/`
    21 durum × 4 pencere + A36 + 11 contact sheet. **Ödül kuralı, seri/tarih
    mantığı, kayıt şeması, ayar yazma yolu, mola eylemleri, sandık kuralı,
    ekonomi DEĞİŞMEDİ.** Round sonu / Devam / Refill dokunulmadı; CandyButton /
    panel_candy / UiPalette / eski ikon klasörü onlar için duruyor (M8.6-10).
    **Owner masaüstü görsel onayı verildi; A36 cihaz kapısı geçti (M8.6-08.1,
    2026-09-18, 3d682e6):** debug APK sızıntısız, native 1080×2340'ta dört
    pencere keskin ve oturmuş X'li, Gizlilik taşması cihazda da yok, anahtarlar
    yalnız kendi alanını yazdı, Günlük claim yalnız kanonik açılış yolunda tam
    bir kez (AL yazmıyor, ikinci claim yok, otomatik açılış çift değil), Mola /
    Sandık / Mağaza onayı rotaları aynı, tek odak kuralı dokunmayla aşılamıyor,
    logcat 0 SCRIPT ERROR / 0 E godot / 0 FATAL / 0 ANR, owner cihaz kaydı
    byte-identical geri kondu; cihaza özel kusur YOK, runtime değişmedi.
    Dal push edildi — **merge izni bekliyor** (`build/qa_m8.6-08/device/`).
    Ayrıntı: UI_VISUAL_SYSTEM §19.
  - `M8.6-09` ✅ **production Round sonu / level tamam / kayıp / ödül reveal**
    (DEVICE VERIFIED, dal `task/027-production-round-result`, main
    2f74a3d üzerine): oyundaki son koyu M8.5-10 sayfası (yarı saydam lacivert
    panel — HUD plakası içinden okunuyordu —, 80 px sandık satırları, İngilizce
    rarity, gerilmiş banner, neon buton + "Level listesi", yalnız aşağı büyüyen
    kutu) kalktı. Tek bileşen üç mod (`UiKit.modal_shell` 600, X yok, **sabit
    `hero`** + kaydırılan `body` + sabit altlık): **WIN** tepelik ×1.18 + altın
    kontur + gövde içi altın kurdele "LEVEL 4 TAMAM!" + yay üstünde üç owner
    yıldızı (0.2 s arayla pop + pırıltı) + yeni kilit rozeti (yalnız bu round
    açtıysa; L10'da "SONSUZ MOD AÇILDI") + **HARİTA** kahraman CTA / TEKRAR OYNA;
    **FAIL** lavanta kurdele "OLMADI", üç yumuşak lavanta kontur yıldız (türev
    `icon_star_empty_soft`), teşvik satırı (ulaşılan tier'a göre), **TEKRAR
    DENE** kahraman / HARİTA; **ENDLESS** "YENİ REKOR!" (altın) / "TUR BİTTİ",
    skor kahraman çipi, REKOR çipi, TEKRAR OYNA / HARİTA. `ResultRewardCard`
    (528×128; skin 176): owner sandığı kapalı→açık (`RewardGem` kalibre
    katmanları), Türkçe rarity etiketi, "+25 HAMUR"; **skin kartında** sandık
    söner ve GERÇEK final sanat 140 px krem kaidede pop'lar + pembe "YENİ SKİN"
    + "Koleksiyon'a eklendi"; geri düşüş "+60 HAMUR" + "Epik skinlerin tamamı
    sende" (skin verildi denmez, iç terim yok); teselli sandıksız lavanta kuyu.
    Altlık çipleri SKOR · HEDEF (+skor satırı) · HAMUR (kanonik bakiyeye sayarak
    varır). 5+ ödülde gövde kaydırılır, altlık/CTA sabit, kartlar dokunma hedefi
    değil (sürükleme kaydırır). Karartma α .74. Main: `show_result`'a salt-okunur
    `newly_unlocked` / `reached_tier`; RESULT_DELAY aralığında mola kilidi
    (eskiden açılan mola sonucu haritanın üstünde bırakabiliyordu). **Yazım
    yolu, sandık kuralı, teselli, yıldız formülü, rotalar, Android geri (yok
    sayılır), devam/refill DEĞİŞMEDİ**; sonuç ağacı kayda yazmaz (kaynak
    taraması + byte kontrolü). `tools/result_ui_test` 226/226 (yapı, kazanma,
    kayıp, ödüller, 6 ödül taşma + sürükleme, kayıt güvenliği + gerçek kayıp
    yolu, rotalar, L10/Sonsuz, devam sırası, 5 yapılandırma, performans);
    `tools/result_shots` 31 kare × 4 boyut + A36 (build/qa_m8.6-09/ before/after
    + 11 contact sheet). Owner masaüstü görsel incelemesini onayladı; **A36
    cihaz kapısı (M8.6-09.1) GEÇTİ, runtime değişmedi**: SM-A366B / Android 16
    / 1080×2340, APK c3c6a0d ağacından (45 620 684 B, 787 girdi, sızıntı 0),
    kabuk cutout'un 167+ px altında ve nav bölgesinin üstünde, HUD karartmada
    %31 (krem gövdeden yazı okunmuyor), yıldız arası ölçülen 207 ms, dört
    rarity + dört skin kartı net, 3/4/5/6 ödül (5 = gerçekçi tavan, cihazda
    kaydırma bile gerekmiyor), kart üstünden sürükleme/fling kaydırıyor,
    gerçek kanonik kazanma yolu tam bir kez yazdı (Hamur 100→110, kilit 1→2,
    yıldız {1:3}), teselli +5 bir kez, ikinci `_finish`/`show_result` kopya
    üretmedi, Android geri yok sayıldı (0 px fark), RESULT_DELAY mola yarışı
    ve Devam→Sonuç sırası doğrulandı, reveal profili ort. 8.8–12.2 ms,
    15 s boşta düğüm/PSS sabit, logcat 0/0/0/0; owner kaydı byte-identical
    geri kondu. İki izleme maddesi (kaydırmada üst kenar kırpması, reveal
    öncesi boş krem gövde) cihazda ölçüldü, dikkat dağıtıcı bulunmadı →
    değişiklik YAPILMADI (zaman çizelgesi kanıtı `build/qa_m8.6-09/device/`).
    Ayrıntı: UI_VISUAL_SYSTEM §20, cihaz notları
    `build/qa_m8.6-09/device/DEVICE_GATE_NOTES.md`.
  - `M8.6-10` ✅ **production Devam (revive) + stok 0 Refill + M8.5 kabuğu
    emekliliği** (DEVICE VERIFIED, dal
    `task/028-production-revive-refill`, main 306dea5 üzerine): son iki M8.5-08
    candy paneli (`panel_candy` gerilmiş + mavi yıldızlı `CandyButton` pill'leri,
    birincil = ikincil) kalktı. **Devam:** `modal_shell` 560 + owner kanatlı-kalp
    tepeliği + "DEVAM ETMEK İSTER MİSİN?", DEVAM HAKKI plakası (owner
    tepeliğinden türetilen `icon_heart_revive` × 2: kalan renkli / kullanılmış
    soluk + "2 / 2", sahte yuva yok), cyan DEVAM ET kahraman (film pictosu,
    "Reklam izle") / lavanta BİTİR; **sağlayıcı yokken DEVAM ET PASİF + "Ödüllü
    reklam henüz bağlı değil."** (aktif görünüp reddeden buton yok), talep
    açıkken kilitli ("Reklam isteniyor…"), X yok / karartma kapatmaz / Android
    geri yok sayılır (değişmedi). **Refill:** pembe kurdele "STOK BİTTİ" +
    oturmuş X, gücün GERÇEK sanatı 112 px candy kuyuda (gücün vurgu rengi) +
    ad + "STOK ×0", iki ayrı kimlikli kart: ÖDÜLLÜ REKLAM (lavanta film kuyusu,
    "Bugünkü hakkın: 1/1", cyan REKLAM İZLE) · HAMURLA AL (altın Hamur kuyusu,
    "120 Hamur" + "Bakiyen: 335", nane SATIN AL); pasif seçenek = pasif buton +
    kartta sebep; KAPAT; **Android geri artık Kapat** (M8.6-07'nin tek boşluğu,
    regresyon testli). **Politika DEĞİŞMEDİ:** 2 devam/round (board sayacı),
    devam yalnız ödül callback'i ile; ödüllü refill 1/gün DÖRT gücün toplamı,
    yalnız `RewardedPolicy.grant` tüketir; fiyatlar `PowerUpEconomy` 100/120/
    160/180 (UI'da sayı yok); tek transaction; pencereler kayda yazmaz; sahte
    reklam / AdMob / billing YOK. **Emeklilik:** `CandyButton`, `UiPalette`,
    `panel_candy.png`, `cta_button_*` / `power_button_*`, `assets/visual/ui/
    icons/` (14 Free Casual GUI türevi — EULA endişesi kapandı) ve
    `make_pack_icons.gd` silindi (production `scripts/`+`scenes/` taraması 0
    referans, testle); `UiType` (game_board "+N"), `UiIcons`, tepelik ve
    temadaki M8.5 rolleri kaldı (UI_VISUAL_SYSTEM §21.6). `UiKit.set_cta_enabled`
    (pasif kahraman CTA'nın yazı/pictosu). `tools/revive_refill_ui_test`
    266/266 (kaynak, devam durumları + işlem sınırı + geri + BİTİR→sonuç sırası,
    dört güç + fiyat + Hamur, ödüllü + paylaşılan kota, satın alma tek
    transaction + çift basış, kapanış yolları, 5 yapılandırma, performans);
    refill 119, revive 120, secondary_modal 102, ui_foundation 165;
    `tools/revive_refill_shots` 17 durum × 4 boyut + A36 (build/qa_m8.6-10/
    before/after + contact sheet'ler). Owner masaüstü görsel incelemesini onayladı;
    **A36 cihaz kapısı (M8.6-10.1, 2026-09-19) GEÇTİ, runtime değişmedi:** SM-A366B /
    Android 16 / 1080×2340, APK 40bab45 ağacından (44 800 970 B, 743 girdi, sızıntı 0,
    emekli asset'ler APK'da YOK), Devam paneli cutout'un 557 px altında / Refill kurdelesi
    376 px altında ve altlık nav bölgesinin 374 px üstünde (kaydırma yok), 2/2 ↔ 1/2 net,
    sağlayıcısız pasif CTA'lar okunur ve dokunuşa/karartmaya/geri ×3'e kapalı (0 talep),
    test sağlayıcısıyla talep tam bir kez / callback tam bir kez / 3. devam yok, gerçek
    taşma → BİTİR → 836 ms boşluk → sonuç (teselli bir kez), Hamur satın alma 500 → 380 /
    stok +1 tek işlem (üçlü dokunuş dahil, güç başına fiyat, yanlış güç yok), ödüllü kota
    Bomba'ya verilince diğer üçünde 0/1 (dört gücün toplamı), sağlayıcı hatası / bekleyen
    talep + geri kota tüketmez ve geç callback reddedilir, geri / X / KAPAT / karartma yazma
    yok, gerçek build'de geçici kayıtla stok 0 tetik + satın alma (380 / bomb 1) + gerçek
    taşma → Devam → BİTİR (405 → 410) doğrulandı; 15 s dinlenmede düğüm/tween/PSS sabit;
    logcat 0/0/0/0; owner kaydı gate boyunca hiç yüklenmedi ve byte-identical geri kondu.
    Cihaza özel kusur YOK. Dal push edildi — **merge izni bekliyor**
    (`build/qa_m8.6-10/device/DEVICE_GATE_NOTES.md`). Ayrıntı: UI_VISUAL_SYSTEM §21.
  - `M8.7-01` ✅ **final gameplay experience denetimi** (dal
    `task/029-final-gameplay-audit`, main fd5dfab üzerine; YALNIZ araç +
    doküman, runtime/fizik/ekonomi/UI DEĞİŞMEDİ, telefon/ADB YOK):
    `tools/gameplay_audit_shots.tscn` (yeni dev harness) §25'teki 29 durumu
    fizik-karesi indeksli kare dizileri olarak çekti — 241 kare × {720×1280,
    1080×2340, 540×960, A36 simülasyonu} = 964 PNG, 0 SCRIPT ERROR, owner kaydı
    her koşuda byte-identical; senaryo başına ses/titreşim olayları, zamanlama
    (kare) ve masaüstü perf (fps tavansız duvar saati) `build/qa_m8.7-01/`
    (GAMEPLAY_FINAL_AUDIT / VFX_INVENTORY / AUDIO_HAPTIC_INVENTORY /
    POLISH_ROADMAP + 19 contact sheet + zoom'lar). **P0 yok:** taşma 90 kare
    = 1.5 s, sarsıntı koruması 72 kare = 1.2 s ve stack etmiyor, devam koruması
    ≈ 1.5 s, merge temas +1 kare, güçler skor vermiyor, tünelleme yok, yerleşince
    mikro hareket 0. **Tek kök-neden sunum kusuru:** `fx_ring.png` yumuşak DOLU
    parıltı, `fx_dot.png` İÇİ BOŞ halka (alfa profiliyle ölçüldü) — gameplay
    tüketicilerinin tamamı tersini varsayıyor → Sarsıntı 500–700 px sis
    lekesi, merge parlaması ince kontur, pop noktaları kabarcık, bokeh "○".
    Diğer P1: dünya "+N" etiketi yeni parçanın yüzünün içinde doğuyor
    (`radius(2)` sabit ofset) ve zincirde üst üste biniyor; Büyütücü'de
    anticipation yok, sütun parçanın arkasında, T7→T8 yükseltmede kral parıltısı
    ve SPECIAL titreşim yok (merge yolundan sapma); kazanma parıltısı kap
    ağzında, kazandıran merge'den 400–600 px yukarıda; T8 parıltısı GAME_DESIGN
    §1 "konfeti"sinin gerisinde. KEEP: düşüş/fizik, temas/gölge, tehlike
    mekaniği, güç sonrası koruma, HUD okunurluğu, kamera. Perf (masaüstü):
    en fazla tek kare 16.7 ms üstü (T8 merge + bomba + büyütücü + sarsıntı
    aynı karede: 19 ms), `_resolve_merge` 2.4–3.6 ms,
    board `_ready` 24–33 ms (level açılışında tek kare) — A36'da doğrulanacak
    liste raporda. Kapı: shell 147, ui_smoke 74, economy 100, refill 119,
    revive 120, audio 45, skin 30, contact_rig, bot L3 2/2. **Öneri: tek
    cila milestone'u M8.7-02 (efekt dili + etiket + Büyütücü + kazanma
    çapası) + A36 kapısı;** P2 listesi planlanmadı. Ayrıntı:
    `build/qa_m8.7-01/GAMEPLAY_FINAL_AUDIT.md`.
  - `M8.7-02` ✅ **final gameplay cilası — merge + güç efekt dili** (dal
    `task/030-final-gameplay-polish`, denetim 623717b üzerine; PRE-DEVICE
    VISUAL REVIEW; fizik/ekonomi/HUD/sonuç/Devam/Refill/RewardGem DEĞİŞMEDİ,
    P2 listesi dokunulmadı, telefon/ADB YOK). Yalnız beş P1: **(A) fx rolü:**
    `GameBoard.GLOW_TEXTURE`=fx_ring.png (dolu parıltı: merge parlaması, bokeh,
    toz), `RING_TEXTURE`=fx_dot.png (içi boş halka: güç halkaları),
    `PopEffect.DOT_TEXTURE`=fx_ring.png; ölçek yardımcıları görünür çapla
    (`_ring_scale`/`_glow_scale`, GLOW_VISIBLE 0.40 / RING_VISIBLE 0.72);
    Kenney ışık dokuları (parıltı/halka/yıldız/patlama) yalnız gameplay'de
    toplamsal `fx_light_additive.tres` materyalinde (siyah saçak → gri duman
    sorunu bitti); halkalar hedef çapına / kap genişliğine göre (Sarsıntı
    0.30→1.0 kap genişliği, eskiden 1.4–2.1 dolu sis); PNG'ler ve RewardGem
    aynen. **(B) dünya "+N":** doğan tier'ın yarıçapı + %25 + 14 px pay
    (T4 28 px, T8 43 px tacın üstünde), gerçek Label boyutuyla deterministik
    kısa ömürlü çakışma önleme (dikey kat, yan yana ise yana kayma, en fazla
    3 adım, canlı etiket listesi spawn'da budanır — yönetici/process yok).
    **(C) Büyütücü:** 0.15 s anticipation (kilitlenme halkası + hedefe bağlı
    yükleme sütunu, `upgrade` sesi dokunuşta) → dönüşüm; stok dokunuşta
    (kanonik), hedef pencerede `is_merging` kilitli, erteleme board tween'i;
    sütun önde (z 5) ve parçanın 1.7 r üstünde (yüz açık); T7→T8 kral
    parıltısı + SPECIAL (parite). **(D) kazanma çapası:** `_check_objective(
    anchor)` → patlama kazandıran merge/Büyütücü noktasında (eskiden kap ağzı,
    580–710 px yukarıda), çapasız tetik yığın tepesi. **(E) T8:** 4.0 r altın
    yıldız (%55 tam opak, 0.62 s) + fx_burst 8 kollu yıldız + çapraz beyaz
    yıldız + 120 ms sonra 14 kıvılcım; T8 pop noktaları altına kayar (bloom
    denendi, 1080'de T8 merge karesini 14→23 ms'ye çıkardığı için ÇIKARILDI). `tools/gameplay_feedback_test` 129/129; `gameplay_audit_shots`
    `polish` grubu (16 senaryo × 4 boyut, before/after) + 3 perf satırı;
    `build/qa_m8.7-02/` 9 contact sheet + rapor. **Owner masaüstü görsel
    onayı GEÇTİ (2026-09-20, T8 ~3 kare/50 ms parlaması "etki" olarak kabul;
    azaltılmadı).**
    **A36 cihaz kapısı (M8.7-02.1, 2026-09-20) GEÇTİ, runtime değişmedi:**
    SM-A366B / Android 16 / 1080×2340 / 120 Hz, üretim APK a3edb40 ağacından
    (44 801 208 B, 745 girdi, sızıntı 0, `fx_light_additive.tres` + tüm yeni
    semboller bytecode'da, harness yok), ayrı QA paketi
    (`tools/gameplay_device.tscn`, kendi veri dizini, sonda kaldırıldı).
    Merge T1/T3/T5/T7 fizik masaüstüyle aynı (temas→çözüm 3 kare), toplamsal
    parıltı Adreno'da temiz (saçak yok), +N 28/33/47 px üstte, etiket çakışması
    0 px², Sarsıntı halkası 144→480 px sis yok, Büyütücü dokunuş→dönüşüm 9–10
    kare, T7→T8 kral parıltısı + SPECIAL (OS `dumpsys vibrator_manager`:
    35+60 ms çiftleri hem merge hem Büyütücü'de, 32 ms MEDIUM, 18 ms LIGHT),
    yarış durumları (aynı hedef / başka hedef / mola / taşma / board silme)
    tek düşüş tek dönüşüm, koruma 72/91 kare, kazanma patlaması merge
    noktasında (d=0) üç rotada, gerçek Main kazanma → sonuç 0.82 s sonra tek
    kez; üretim paketinde gerçek dokunuşla iki L1 kazanma (patlama T4'te,
    sonuç, harita L2 açık, kayıt bir kez). Perf (aynı telefonda 623717b ile
    a3edb40 art arda, 3'er geçiş): ortalama 8.4 ms (vsync 120 Hz); merge
    karesi T3 23–24 → 17–23 ms, T8 26 → 19–24 ms, Büyütücü dokunuş karesi
    22–24 → 15–17 ms, many-effects 31–32 → 25–29 ms; >25 ms yalnız açılıştan
    sonraki İLK merge (her iki build'de 45–67 ms) ve level açılışı `_ready`
    (57–120 ms); 10× T8 / 10× Sarsıntı / 10× Büyütücü / 10× merge sonrası
    geçici düğüm 0, tween 0, statik bellek sabit, PSS 359→268 MB. Logcat
    0/0/0/0/0/0 (tek AdrenoVK satırı Android framework'ün kendi Vulkan
    örneği). Owner cihaz kaydı byte-identical geri kondu (md5 942aa5c3,
    sha256 9af78146, cmp), uygulama force-stop. Cihaza özel kusur YOK. Not:
    merge karesi ~23 ms (120 Hz'de 2–3 vsync) her iki build'de var — polish
    değil, ileride optimizasyon adayı. Dal push edildi — **merge izni
    bekliyor** (`build/qa_m8.7-02/device/DEVICE_GATE_NOTES.md`).
  - `M8.8-01` ✅ **production ses kaynak denetimi + aday paleti** (dal
    `task/031-production-audio-audit`, main 0abd22b üzerine; YALNIZ Python
    araç + doküman, runtime/`AudioManager`/`Haptics`/GameBoard/`project.godot`
    DEĞİŞMEDİ, repoya ses import edilmedi, telefon/ADB YOK). Owner'ın indirdiği
    Kenney Impact / Interface / UI / Music Jingles (CC0) + Sonniss GDC 2026
    Part 9 (royalty-free, atıf yok, **AI eğitimi yasak**) paketleri
    `D:\dev\squishy-audio-source` altında (repo dışı, gitignore'lu
    `_audio_source/` DEĞİL) indekslendi: 715 dosya (368 OGG + 347 WAV, 8.0 GB),
    lisanslar paketlerdeki dosyalardan okundu, her dosyaya seçim ölçümleri
    (tepe/RMS/centroid/flatness/transient/bant payları/pitch yönü).
    `tools/audio_source_audit.py` (envanter) + `tools/audio_audition_export.py`
    (kısa liste → `build/qa_m8.8-01/auditions/<kategori>/` orijinal kopya +
    `auditions_normalized/` yalnız dinleme için −20 dBFS RMS eşitlenmiş kopya)
    izole venv ile (`squishy-audio-source\.venv`, numpy + soundfile; ffmpeg yok).
    Sonuç: 13 kategoride 164 aday (123 tekil dosya; STRONG/ALT/REF gerekçeli),
    `FINAL_AUDIO_PALETTE.md` (her olay için birincil + 2 alternatif + işleme),
    `MERGE_SOUND_FAMILY_BLUEPRINT.md` (4 kaynaktan tek merge ailesi: bubble pop +
    Kenney generic/plate gövde + tiny glass + bell chime, T8 = bell bloom + music
    box + arp kuyruğu; tier başına pitch/gain/katman/ofset), `HAPTIC_ALIGNMENT.md`
    (runtime eşlemesi olduğu gibi raporlandı — **fark:** T1–3 merge LIGHT,
    brief "yok ya da mevcut minimal" diyor; değiştirilmedi),
    `AUDIO_SOURCE_PROVENANCE.md`, `LISTENING_ORDER.md`, owner dinleme paketi
    `M8.8-01_audio_review_bundle.zip` (73.7 MB). Kritik ölçüm: mevcut
    `kenney_impact_soft_01.ogg` (iniş + merge gövdesi) enerjisinin %100'ü
    200 Hz altında → telefon hoparlöründe duyulmuyor; öneri Kenney
    `impactPunch_medium_001` / `impactPlate_*`. Müzik: kütüphanelerde uygun loop
    YOK (v1 non-goal zaten). Hiçbir ses kulakla doğrulanmadı — owner dinleme
    onayı sonrası M8.8-02 entegrasyon. Kapı: audio_test 45/45, ui_smoke 74/74
    (ui_smoke kaydı yazdı, owner kaydı byte-identical geri kondu).
    **01.1 owner dinleme kısa listesi (2026-09-20, aynı dal):** 164 aday owner
    için çok fazlaydı → `tools/audio_owner_shortlist.py` ile **43 dosya**
    (`build/qa_m8.8-01/owner_shortlist/NNN_ROL__orijinal-ad.wav`, yalnız gain
    eşitleme, kompresyon/EQ yok; 250 Hz–3 kHz telefon bandı payı ölçülüp
    raporlandı, seçim için kullanılmadı — metrik yalnız bariz sorunu eler,
    zevk gerektiren yerde gerçek alternatif kaldı). Merge ailesi BODY A/B/C ·
    SPARKLE A/B · LARGE BODY A/B · T8 BLOOM A/B · T8 TAIL A/B etiketli;
    gövde kaynakları telefon bandı ölçümüyle `impactPlate_light_003` /
    `impactPlate_medium_001` kardeşlerine kaydı (ince/parlak DEĞİL, aynı aile,
    daha çok orta bant). **STILL WEAK:** Sarsıntı ve sandık açılışı — sonra
    hedefli tek ses kaynaklanacak. `OWNER_LISTENING_GUIDE.md` (4 soru:
    yumuşak mı / 100 kez bıkar mı / dumpling'e yakışır mı / premium mi) +
    puanlama tablosu; paket `M8.8-01_OWNER_AUDIO_SHORTLIST.zip` (6.2 MB, 43
    ses + 4 doküman, 164'lük havuz yok). Runtime yine DEĞİŞMEDİ.
  - `M8.8-02` ✅ **production ses entegrasyonu + final SFX/titreşim hizası**
    (dal `task/032-production-audio-integration`, `task/031` 1dd9c1e üzerine =
    main 0abd22b → denetim → entegrasyon; PRE-DEVICE: masaüstü kapı geçti,
    telefon/ADB YOK, push/merge YOK). Owner'ın dinleme kararları uygulandı:
    **merge A (premium)** — POP (`Cartoon Bubbles Short`, iki kabarcık = iki
    varyant, kilitli 0.85→1.48 pitch) + tier bandı gövde havuzları (T1–3
    `impactGeneric_light`, T4–6 `impactPlate`, T7–8 `impactPunch_medium_001`) +
    T3+ cam parıltısı (+30 ms) + T5+ çan (+45 ms) + T8 bloom (+20) / müzik kutusu
    (+70) / kuyruk (+120 ms), T8 ilk 50 ms −14 dBFS = T5–6 ile aynı, 0.9 s uzun
    (gürültülü değil geniş); **Büyütücü C** dokunuşta yükseliş, dönüşümde ölçülü hava
    + merge ailesi (150 ms değişmedi); **drop C** (`impactGeneric_light_001`, iniş +
    −18 dB bırakma tik'i); **Bomba A** fırlatma/vuruş/+15 ms puf; **Temizleyici B**
    3 dilimlenmiş pop + altta süpürme; **win/fail B/B** (STEEL09 / PIZZI00); **sandık
    A** (mandal, owner kararı); Hamur `Ting Coins`; **UI** tek Kenney Interface
    ailesi (TAP/CONFIRM/BACK/ERROR); owner'ın reddettiği kategorilerde Claude seçimi:
    Sarsıntı = `Accept Boing Crunch` warble (375–1100 Hz, 0.45 s), tehlike =
    `impactWood_light_001/003` yumuşak ahşap tok, Legendary = onaylı katman
    kompozisyonu (bloom + kutu + yükselen kutu + kuyruk). 35 WAV 44.1 kHz/16-bit/mono
    (`tools/audio_production_build.py`, deterministik, `docs/audio/PRODUCTION_FILES.md`;
    22 sentez + 5 Kenney OGG + `make_sfx.gd` silindi; `.import` PCM). Runtime:
    `delay_ms` gecikmeli katmanlar (SceneTreeTimer, process yok, `stop_all`
    iptal), iç içe katman ağacı, fallback zinciri, `MERGE_RECIPE` tier tablosu.
    **Titreşim owner kararı:** normal merge T1–T3 YOK / T4–5 LIGHT / T6–7 MEDIUM /
    T8 SPECIAL (`Haptics.merge_tier`), güçler aynen; ses/titreşim hizası gövdede.
    Kanonik doküman: `docs/audio/AUDIO_SYSTEM.md` + `MERGE_SOUND_FAMILY.md` +
    `HAPTIC_MAPPING.md`; `AUDIO_AUDIT` / `AUDIO_ASSET_REQUIREMENTS` tarihsel işaretli;
    `CREDITS.md` + `docs/licenses/audio/`. `tools/audio_test` 116/116 (yeni suite),
    `tools/audio_event_render` 30 senaryolu entegre dinleme paketi
    (`build/qa_m8.8-02/audition/`). Kapı: gameplay_feedback 129, shell 147, ui_smoke
    74, result_ui 226, revive_refill_ui 266, economy 100, refill 119, revive 120,
    skin 30, bot L3 2/2; owner kaydı byte-identical. **Fizik, skor, ekonomi, güç
    mekaniği, kayıt şeması, görsel DEĞİŞMEDİ** (game_board.gd'de yalnız 3 ses/titreşim
    satırı). Sıradaki: owner masaüstü dinleme incelemesi → A36 cihaz kapısı.
    **A36 cihaz kapısı (M8.8-02.1, 2026-09-21) GEÇTİ — bir dar ses-only düzeltmeyle
    (`a60f501`):** SM-A366B / Android 16 (BP4A…CCZH1) / 1080×2340 / oyunda 120 Hz,
    üretim APK `de5be7b` ağacından (44 901 473 B, 761 girdi, sızıntı 0, tam 35 PCM
    örnek, SFX bus + limiter, yeni semboller bytecode'da, eski yok), ayrı QA paketi
    (`tools/audio_device.tscn`: gameplay_device üstüne komut başına SFX bus yakalama →
    WAV + tepe/kırpma, olay sayaçları + ilk-son çalma anı, kanal/bekleyen tavanı,
    titreşim zaman çizelgesi, ekranda 6 düğmeli owner dinleme paneli; sonda kaldırıldı).
    54 + 7 cihaz yakalamasında **0 kırpılmış örnek**; hoparlör merdiveni en gür 50 ms
    T1 −13.0 · T3 −12.8 · T4 −12.9 · T6 −13.7 · T8 −13.2 dBFS (T8 daha uzun, daha gür
    değil; bloom/kutu/kuyruk cihazda +20/+50/+99 ms). Titreşim merdiveni sink + OS
    `dumpsys vibrator_manager` ile kanıtlandı: T1–T3 hiç, T4/T5 18 ms, T6/T7 32 ms, T8
    35+60 ms (OS 34/35/51/48/51/74 ms, aynı anlar); 24 merge/0.4 s spam'de 12 kanal
    tavanı, limiter devrede, kırpma 0, 12 darbe bastırıldı. Gerçek yollar: Bomba
    (fırlatma → +290 ms vuruş + +22 ms puf, tek STRONG), Sarsıntı (tek MEDIUM),
    Temizleyici (süpürme + parça başına pop, tek LIGHT), Büyütücü T4→T5 +154 ms tek
    MEDIUM / T7→T8 +174 ms tam T8 yığını + tek SPECIAL, tehlike → fail + revive.
    Mute / titreşim kapalı / mola / board silme / stop_all / arka plan: yetim katman 0,
    pending 0, çökme 0. Perf 120 Hz ort 8.4 ms, T8 merge karesi 17.6–22 ms (M8.7-02.1 ile
    aynı bant). **Owner hoparlör dinleme kontrolü: 5 senaryoda PASS** (merge dizisi, T8,
    Sarsıntı, tehlike, Legendary). Bulgu → düzeltme: 0.3–1.1 s arayla iki T8 (zincir /
    Büyütücü / sonsuz yok oluşu) ikincinin bloom'unu düşürüyordu (`max_voices` 1, bloom
    1.1 s) → üç T8 katmanında `max_voices` 2 (soğuma aynı), audio_test 117/117, cihazda
    yeniden doğrulandı (2/2/2). Üretim paketinde gerçek dokunuşlarla L1: T3+T3 LIGHT →
    kazanma → Common sandık LIGHT (tur boyunca 2 titreşim), tekrar oyunda T2+T2 merge 0
    titreşim, Sarsıntı MEDIUM / Bomba STRONG (stok 3→2, skor değişmedi). Logcat 57 550
    satır: 0/0/0/0/0/0. Owner cihaz kaydı (671 B, md5 942aa5c3, sha256 9af78146) byte-identical
    geri kondu, uygulama force-stop. Post-device masaüstü kapı yeşil (audio 117, feedback
    129, shell 147, ui_smoke 74, result_ui 226, revive_refill_ui 266, economy 100, refill 119,
    revive 120, skin 30, bot L3 2/2; masaüstü kaydı byte-identical). Kanıt
    `build/qa_m8.8-02/device/DEVICE_GATE_NOTES.md`. Dal push edildi — **main'e merge
    edilmedi** (owner kararı bekliyor).
  - `M8.9-01` ✅ **AdMob monetizasyon temeli — ödüllü devam + ödüllü refill +
    banner + UMP rıza** (dal `task/033-admob-monetization-foundation`, main
    93aa25b üzerine; TEST REKLAMI, telefon/ADB YOK, push/merge YOK). Araştırma:
    `godot-sdk-integrations/godot-admob` **v6.0** (2026-02-01, MIT, godot-lib
    4.6.stable; v7.0 Godot 4.7 beta1 hedefli, bakımcı "4.6.x → v6.0" diyor),
    play-services-ads **24.9.0** (Supported, deprecation 2027-06-30), UMP
    **3.2.0**; Google'ın "Next-Gen SDK"sı eklentiye bağlı, v1 için gerekmez.
    Eklenti release zip'i olduğu gibi `addons/AdmobPlugin/` (kaynak
    değişmedi, VERSION.md + LICENSE), `android_export.cfg` = is_real=false +
    Google örnek kimlikleri ([Release] boş; `AdConfig` gerçek modda boş/örnek
    kimlikte reklamı başlatmaz). Mimari: `MonetizationManager` (Main'in çocuğu,
    4. autoload YOK; eklentisiz platformda yaratılmaz → eski sağlayıcısız
    davranış) → `AdBackend` (soyut) → `AdmobBackend` (eklenti) / `FakeAdBackend`
    (tools, test). Rıza: her açılışta UMP update → gerekirse form → SDK
    başlatma; durumlar CONSENT_CHECKING / CONSENT_FORM / ADS_ALLOWED /
    ADS_NOT_ALLOWED / ERROR_WITH_PREVIOUS_STATE; SDK tek gerçek, önbellek yok,
    spinner yok. Ödüllü: IDLE→LOADING→READY→SHOWING→REWARD_EARNED→DISMISSED /
    FAILED, tek reklam aynı anda, talep bağlamı (tür/güç/token/ad_id) ile çift/
    geç/eski/iptal callback'leri elenir; ödül YALNIZ `Main.grant_revive` /
    `grant_rewarded_power` (kilitli 2/round ve 1/gün toplam DEĞİŞMEDİ); önyükleme
    + 5/15/45/120/300 sn geri çekilme (8 deneme, pencere açılışı yeniler), 60 s
    zaman aşımı, öne dönüş payı. Pencereler: CTA yalnız yüklüyken aktif;
    "Reklam hazırlanıyor…" / "Reklam şu anda kullanılamıyor." / "Ödül için
    reklamın tamamını izlemen gerekiyor."; pencere açıkken yüklenince CTA
    açılır. Banner: uyarlanabilir sabit, alt, güvenli alan içinde; yalnız Ana
    Sayfa / Mağaza / Koleksiyon; oyun + sonuç + **Harita banner dışı** (level 1
    düğümü alt %12'de); yuva (`UiKit.bottom_inset`) açılışta bir kez, oturum
    boyunca sabit (zıplama yok). Ayarlar: gizlilik metni AdMob'u anlatıyor;
    "Gizlilik seçenekleri" satırı yalnız SDK form sunuyorsa. `AdEvents` olay
    dikişi (12 olay, sağlayıcı yok). Android: Gradle build'e geçildi (yerel
    preset), `--install-android-build-template` ile 4.6.3 şablonu; export OK
    (minSdk 24 / target 36, test APPLICATION_ID manifest'te, sızıntı 0); debug
    APK 102 MB (Gradle debug .so strip'siz — release'te küçülür).
    `tools/monetization_test` **181/181**; tam gate yeşil (audio 117, feedback
    129, shell 147, ui_smoke 74, result_ui 226, revive_refill_ui 266, economy
    100, refill 119, revive 120, skin 30, home_ui 207, shop_ui 212,
    collection_ui 164, secondary_modal 102, ui_foundation 165, map_ui 127, bot
    L3 2/2). **Fizik, ekonomi, kota, kayıt şeması, gameplay/ses DEĞİŞMEDİ.**
    **A36 test-reklam cihaz kapısı (M8.9-01.1, 2026-09-21) GEÇTİ — bir dar
    düzeltmeyle:** SM-A366B / Android 16 / 1080×2340 / yoğunluk 450; ayrı QA
    paketi (`tools/ads_device.tscn`, komut/durum dosyası, gerçek dokunuşlar) +
    üretim paketi (geçici kayıt). TR coğrafyasında UMP NOT_REQUIRED → SDK init
    → 6 s içinde gerçek Google test banner'ı (Ana Sayfa / Mağaza / Koleksiyon,
    1080×168 px, yuva 169,5 px, OYNA/son satır üstte) ve hazır test ödüllü
    reklam; Harita / oyun / sonuç ekranında banner yok, gezinme döngüsü ×3 tek
    AdView, sızıntı yok. Gerçek test ödüllü reklamla devam ×2 (çift dokunuş → tek
    gösterim; reklam sırasında HOME → dönüş tek kapanış; ödül callback'i reklam
    hâlâ üstteyken geliyor → grant tam bir kez), üçüncü teklif pasif; üretim
    paketinde gerçek taşma → gerçek teklif → test reklamı → devam. Refill: Bomba
    gerçek reklamla +1, kota 1→0, Sarsıntı'da CTA pasif (kota dört gücün toplamı),
    Hamur yolu bağımsız. Gerçek no-fill (geçersiz kimlik, SDK kod 3) → dürüst
    "kullanılamıyor" + sınırlı geri çekilme; sahte arka uçla gösterim hatası /
    round terki / KAPAT yarışları ödül vermedi. Logcat 0 SCRIPT ERROR / 0 FATAL /
    0 ANR; tek E/godot kusuru = yönetici sökülürken eklentinin zaten kaldırdığı
    banner'a `hide` → `AdmobBackend` kimliği önbellekte yoksa atlar (dar düzeltme).
    Owner görsel kontrolü (Ana Sayfa / Mağaza / Koleksiyon banner + bir ödüllü
    geçiş): **PASS**. Owner kaydı byte-identical geri kondu, QA paketi kaldırıldı.
    **ÜRETİM ENGELLERİ (kapı geçse de açık):** (a) eklenti v6.0 UMP
    `canRequestAds` / `getPrivacyOptionsRequirementStatus` /
    `showPrivacyOptionsForm`'u sarmıyor VE `debug_geography` cihazda uygulanamıyor
    (upstream #120: Java `Integer` bekliyor, Godot `Long` gönderiyor) → EEA rıza
    formu cihazda gösterilemedi; üretim öncesi küçük eklenti yaması (AAR) ya da
    upstream PR kararı gerek; (b) COPPA/TFCD/TFUA + kitle kararı; (c) AdMob hesabı
    (App ID, 2 reklam birimi, Privacy & messaging mesajı) — üretim kimliği yok.
    Kanonik: `docs/monetization/ADS_SYSTEM.md` §12, `PRIVACY_CONSENT.md` §4/§7.
    **Main'e alındı (33b6382, 2026-09-21, ff-only, push edildi) — M8.9-01 KAPANDI,
    test-reklam temeli DONDURULDU.**
  - `M8.9-02` ✅ **monetizasyon genişletmesi + günlük ödüller** (dal
    `task/034-monetization-daily-rewards`, main 33b6382 üzerine; TEST REKLAMI,
    telefon/ADB YOK, push/merge YOK; owner ürün kararları). Araştırma: Google
    interstitial belgeleri (2026-09-21) + eklenti v6.0 `Interstitial.java`
    (`InterstitialAd` / `InterstitialAdLoadCallback` / `FullScreenContentCallback`
    sarılı) → özel köprü gerekmedi. **Banner:** Harita + oyun ekranı da yüzey
    (`BANNER_SURFACES` 5; sonuçta gizli); oyun `GameplayLayout` seam'i canlı
    yuvayla dolar (kompakt aralık modu 16:9; **fizik/kap/FLOOR_Y/yarıçap
    DEĞİŞMEDİ**, 720×1280 zoom 0,971→0,874, A36 L1–L3 aynı), Harita dünyası
    yuvanın üstünde biter (`_fit_world`; 16:9'da zemin dikeyde %3,4
    sıkıştırma, A36'da birebir cover). **Geçiş reklamı:** `MonetizationManager`
    interstitial durum makinesi (IDLE/LOADING/READY/SHOWING/DISMISSED/FAILED,
    tek önbellek, 55 dk tazeleme, 15/60/180/600 sn geri çekilme), aktif süre
    saati (900 sn; arka plan / UMP formu / tam ekran reklam / onboarding
    sayılmaz), YALNIZ `Main._on_round_finished` doğal molasında
    `try_show_interstitial` → sonuç reklam kapanınca tam bir kez (`_result_seq`),
    hazır değilse sonuç hemen, saat yalnız gerçek gösterimde sıfırlanır, 60 sn
    tam ekran beklemesi, ödüllü ↔ geçiş dışlaması, 5 s gösterim onay zaman
    aşımı. Test birimi `…/1033173712`, `[Release] interstitial_id=""` (fail-closed).
    **Günlük ödüller:** `DailyRewards` (tek yetkili model: yerel gün anahtarı +
    geri alma koruması `last_seen_day_key`, üç AYRI kota, tek transaction'lar),
    `DailyChestLoot` (+15 garanti, %30 skin, 60/25/12/3, sahip olunmayan skin,
    tükenmişse +15 bonus = +30; level sandığı reçetesi DEĞİŞMEDİ),
    `DailyChestReward` (değişmez sonuç), `SaveManager.daily_rewards` +
    `claim/grant_daily_*` (kota + Hamur + skin tek yazma). Reklamlı yollar
    `RewardedKind.DAILY_CHEST / DAILY_DOUGH` + gün anahtarı + token; ödül yalnız
    `Main.grant_daily_chest / grant_daily_dough`. **UI:** `DailyRewardsPopup`
    (pembe kurdele, üç seçenek kartı, HAZIR/ALINDI/REKLAM HAZIRLANIYOR/2 / 2/
    BUGÜNLÜK BİTTİ, KAPAT; reveal: owner sandığı → +15 HAMUR → YENİ SKİN kartı,
    DEVAM ~1,2 s), Mağaza en üstte GÜNLÜK ÖDÜLLER kartı (HAZIR / N ödül kaldı /
    BUGÜNLÜK TAMAMLANDI), otomatik pencere günde bir (giriş ödülü penceresinden
    SONRA; kapatmak ödül tüketmez), pencereler banner'ın üstünde ortalanır.
    **Onboarding dikişi:** `onboarding_completed` (yeni kayıt false; eski kayıt
    ilerleme kanıtıyla true — level > 1 / yıldız / merge / rekor / skin; Hamur
    kanıt değil; karar bellekte, disk sonraki kayıtta); false iken banner/yuva,
    geçiş, günlük pencere/kart, ödüllü sunum yok; `complete_onboarding()` +
    `set_onboarding_completed(true)` M8.10 sözleşmesi. Olay dikişi 28 olay.
    Testler: `daily_rewards_test` **111**, `interstitial_test` **60**,
    `monetization_test` **191**; tam gate yeşil (audio 117, feedback 129, shell
    147, ui_smoke 74, result_ui 226, revive_refill_ui 266, economy 100, refill
    119, revive 120, skin 30, home_ui 207, shop_ui 213, collection_ui 164,
    secondary_modal 102, ui_foundation 165, map_ui 127, bot L3 2/2). Görsel:
    `tools/daily_ads_shots` 3 boyut (build/qa_m8.9-02/). **Fizik, ekonomi,
    level sandığı, ses/titreşim, kayıt anlamı DEĞİŞMEDİ.**
    **02.1 (owner kararı, aynı dal):** giriş ödülü + GÜNLÜK ÖDÜLLER **tek
    pencere** — eski `DailyRewardPopup` üründen/repodan kaldırıldı; giriş
    ödülü (+15/seri, ekonomi aynı) pencereden ÖNCE tek işlemle çözülüp üst
    bölgede "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi olarak gösteriliyor
    (kapat/aç ikinci +15 yok); Ana Sayfa madalyonu ve Mağaza kartı aynı
    pencere; onboarding false iken `DailyReward.claim_if_new_day` kaydı HİÇ
    değiştirmiyor (Hamur/seri/tarih); Legendary reveal halesi kırpılmıyor.
    daily_rewards_test 134, secondary_modal 100, home_ui 208; tam gate yeşil.
    **A36 cihaz kapısı (M8.9-02.2, 2026-09-22) GEÇTİ, runtime değişmedi:**
    SM-A366B / Android 16 / 1080×2340 / 120 Hz, resmî Google TEST kimlikleri,
    üretim APK'sı 6bfa97f ağacından byte-identical (`356b0501…`), ayrı QA
    paketi (`tools/ads_device` + M8.9-02.2 QA komutları; üretimde yok).
    Doğrulanan: otomatik GÜNLÜK ÖDÜLLER penceresi açılışta TAM BİR KEZ + giriş
    +15 tam bir kez (madalyon/Mağaza aynı pencere, ikinci +15 yok), ücretsiz
    sandık çift dokunuş tek transaction, gerçek test ödüllü reklamla 2 sandık
    (biri gerçek skin kurası) + +150 tam, kotalar ALINDI/BUGÜNLÜK BİTTİ ve
    refill/devam'dan bağımsız, Efsanevi reveal halesi pencerede, Harita banner'ı
    (Level 1 OYNA plakası banner'ın 146 px üstünde) ve oyun banner'ı (hiçbir
    etkileşimli öğeyi örtmüyor, dokunuşlar Godot'a ulaştı), banner yaşam
    döngüsü tek AdView / sonuçta gizli, **gerçek test interstitial'ı doğal
    molada** (900 sn → uygun; BİTİR → reklam → kapanış → Sonuç bir kez; saat
    yalnız SDK gösteriminde sıfırlandı; 60 sn bekleme; uygun değil / bekleme /
    hazır değil / gösterim hatası yollarında Sonuç hemen, uygunluk korundu),
    ödüllü reklam ve arka planda saat durdu, yeni kayıtta tam bastırma, gün
    değişimi/geri saat, logcat temiz (E/godot 0), PSS 431–501 MB ilerleyen
    büyüme yok; owner görsel kontrolü 5/5 PASS; owner kaydı byte-identical.
    Kanıt `build/qa_m8.9-02.2/` (yerel). **Main'e alındı (9561a4c, 2026-09-22,
    ff-only, push edildi) — M8.9-02 KAPANDI, TEST-reklam monetizasyon deneyimi
    DONDURULDU;** dal `task/034` duruyor. Entegrasyon kapısı ilk koşuda yeşil
    (20 suite, `build/qa_m8.9-02_integration/`), main'den export edilen
    TEST-reklam APK'sı cihaz kapısındakiyle birebir (`356b0501…`).
    M8.10 ilk gün kuralı yalnız dokümante (DAILY_REWARDS §9), UYGULANMADI.
  - `M8.10` ⏳ **İlk açılış tutorial'ı + ilk gün günlük kuralı** (dal
    `task/035-first-run-tutorial`, base `d72fde5`). **Gerçekten yeni oyuncu**
    (`onboarding_completed == false`) açılışta doğrudan GERÇEK Level 1
    tutorial'ına giriyor — Ana Sayfa/Harita yolculuğu yok, reklam yok, UMP
    formu yok, günlük ödül mutasyonu yok. Adımlar: karşılama (maskot + BAŞLA)
    → ilk bırakma (gerçek sürükle/bırak, güvenli banda clamp) → eşleştirme
    (ikinci T1 birinciye SNAP) → **GERÇEK merge** (production `_resolve_merge`
    T2'yi doğuruyor; sahte fizik/sahte T2 YOK, tutorial T2'si board'da kalıyor)
    → kısa kutlama → hedef / tehlike çizgisi / güçler spot'ları → hazırsın.
    Öğretim kuyruğu `[T1, T1]` tutorial'a özel; **normal DropBag RNG'sine
    DOKUNULMUYOR**. Küçük **ATLA** her an var (ana CTA değil) ve aynı kanonik
    tamamlanma yolundan geçiyor; Android geri "DEVAM ET / ATLA" onayı açıyor,
    monetize Ana Sayfa'ya düşülmüyor. Yeni `Onboarding` servisi + kayıt alanı
    `onboarding_completed_day`: tamamlanma **tek transaction** (iki alan +
    `last_seen_day_key`), idempotent. **İlk gün kuralı:** tutorial'ın
    bitirildiği takvim gününde günlük sistemin TAMAMI kapalı (+15/seri/pencere/
    üç kota/Mağaza bölümü/madalyon), telafi yok; ertesi yerel günde sıfırdan.
    Kapı modelde (`Onboarding.daily_rewards_unlocked`), UI'da değil. Eski
    kayıtta tamamlanma günü BOŞ = yerleşik oyuncu, bastırma YOK. **UMP/rıza
    akışı onboarding'e kadar hiç başlamıyor** (şart kaldırılmadı, ertelendi);
    tutorial'dan doğan round'un ORTASINDA banner yuvası açılmıyor — bir
    sonraki güvenli kabuk/round geçişinde. Eski "Level 1 sürükle • bırak"
    ipucu KALDIRILDI (iki tutorial yarışmıyor). Yeni: `tutorial_controller`,
    `tutorial_overlay` (katman 8), `onboarding`, `tutorial_events`,
    `tools/tutorial_test` (199), `tools/tutorial_shots`. **Durum: masaüstü
    kapısı + görsel QA tamam, A36 cihaz kapısı GEÇTİ (M8.10.1), main'e
    alındı `3fb2945` (ff-only, push edildi).** Doküman:
    `docs/TUTORIAL_SYSTEM.md`.
  - `M8.10.1` ✅ **A36 ilk açılış tutorial'ı cihaz kapısı GEÇTİ**
    (2026-09-22; TUTORIAL_SYSTEM §12.1). SM-A366B / Android 16 / 1080×2340,
    aynı ağaçtan iki APK (üretim biçimli TEST-reklam + ayrı QA paketi).
    **Gerçek dokunuşla:** silinmiş kayıtla açılış doğrudan Level 1
    tutorial'ına girdi (Ana Sayfa/Harita/günlük/banner/UMP yok, log'da rıza
    satırı SIFIR); uçtan sürüklemede CLAMP çalıştı; parça doğduğunda adım
    gözlem penceresi boyunca bekledi (doğuş karesinde "oturdu" saymadı);
    hedeften uzağa bırakılan ikinci T1 hizalandı ve **gerçek T1+T1 → T2**
    (skor 50, merge 1) oldu; üç coach mark hedefi örtmeden vurguladı.
    Tamamlanmada diske YALNIZ iki alan + `last_seen_day_key` yazıldı
    (giriş tarihi/seri/Hamur/üç kota/`popup_seen_day` dokunulmadı). Round
    ortasında dört drop daha: **banner yuvası 0, geometri aynı, UMP 0**;
    kabuğa dönüşte UMP **0 → 16** (TR/EEA dışı → NOT_REQUIRED), SDK açıldı,
    test banner'ı doğru yuvayla geldi; üç Ana Sayfa↔Harita turu + arka
    plan/öne dönüş ikinci rıza güncellemesi üretmedi. Aynı gün günlük tam
    bastırma (madalyon noktasız ve yanıtsız, Mağaza bölümü gizli, kayıt
    değişmedi); ertesi gün +15 bir kez + seri 1 + tek pencere + tam kotalar;
    saat geri alınınca ikinci ödül/bastırma/tutorial yok. Yarıda force-stop
    → WELCOME'dan baştan, onboarding false. ATLA ve Android geri kanonik
    yoldan; geri onayı monetize Ana Sayfa'ya düşürmedi. Mevcut oyuncu ve
    eski kayıt migration'ı tutorial görmedi (tamamlanma günü BOŞ kaldı);
    onboarded Level 1 tekrarında hiçbir tutorial öğesi yok. Logcat temiz
    (0 SCRIPT ERROR / E-godot / FATAL / ANR / tombstone / sızıntı), PSS
    475 MB, düğüm 3175 → 3179, orphan 0. **Owner görsel kontrolü PASS
    (5/5).** Owner telefon kaydı byte-identical geri kondu (916 B, md5
    `53df9bee…`); QA paketi kaldırıldı. Cihazda runtime defekti YOK —
    üretim kodu değişmedi. Cihazdan sonra masaüstü kapısı yeniden yeşil
    (20 suite + 2 bot). **Dal push edildi; main'e BİRLEŞTİRİLMEDİ.**
    Kanıt: `build/qa_m8.10.1/` (yerel).
  - `M9-01` ✅ **Android production release hazırlığı — kod tarafı** (dal
    `task/036-production-release-readiness`, base `5a3a0f0`; **M9-01.1 ile
    birlikte 2026-09-24'te main'e ff-only alındı**; M9-01 oturumunda
    telefon/ADB YOK; oyun/UI/tutorial/ekonomi DEĞİŞMEDİ). (1)
    **AdMob eklentisi UMP yaması:** upstream v6.0/v7.0/main UMP
    `canRequestAds` / `getPrivacyOptionsRequirementStatus` /
    `showPrivacyOptionsForm`'u sunmuyor; v6.0'a 3 dosyalık yama (+ #120
    `debug_geography` Long düzeltmesi), AAR'lar deterministik yeniden
    derlendi (`tools/admob_plugin/`: yamasız derleme upstream AAR'larıyla
    sınıf sınıf aynı, yamalı derleme 3 kez BYTE-IDENTICAL). (2) **Rıza:** izin
    kapısı resmî `canRequestAds()` (SDK başlatma + her yükleme öncesi),
    güncelleme hatasında önceki oturumun rızası korunur, gizlilik seçenekleri
    resmî durum + resmî form, yamasız eklentiye uyarılı geri düşüş. (3)
    **Kimlikleri build türü seçer:** debug = yalnız Google test (canlı birim
    imkânsız), release = dört gerçek kimlik + `is_real=true`, aksi hâlde
    fail-closed; debug coğrafyası yalnız debug build (EEA / NOT_EEA QA
    kancaları). (4) `[Audience]` dikişi (TFCD/TFUA/derece — owner kararı
    bekliyor, değerler M8.9'daki gibi). (5) **Release kapısı** (`tools/release/`:
    tek doğrulayıcı `ReleaseReadiness`, `release_android.sh check|aab|
    non-publishable-aab|debug-apk`, `addons/squishy_release` export'u Gradle'da
    bilerek düşürür) + tek sürüm kaynağı (project.godot `[squishy]`) + Ayarlar
    "Gizlilik politikası" satırı (URL verilene kadar gizli). Testler:
    `release_config_test` 106 (yeni), `monetization_test` 222 → 248, tam
    regresyon yeşil (21 suite + bot L3 2/2, 0 SCRIPT ERROR, owner kaydı
    byte-identical). Çıktılar: TEST-reklam debug APK (Google test kimlikleri,
    sızıntı 0) + İMZASIZ `NOT_FOR_UPLOAD` release biçimli AAB (hat doğrulaması,
    Play'e yüklenemez). **Upload-ready AAB YOK — kapı BLOCKED:** paket kimliği,
    gerçek AdMob kimlikleri, kitle kararı, gizlilik politikası URL'i, upload
    anahtarı owner'da. Dokümanlar: `docs/ANDROID_RELEASE_CHECKLIST.md`,
    `docs/DATA_SAFETY_INVENTORY.md`, `docs/monetization/AUDIENCE_DECISION.md`.
  - `M9-01.1` ✅ **UMP / gizlilik cihaz kapısı — Samsung A36 GEÇTİ, runtime
    değişmedi** (2026-09-23, aynı dal; 2026-09-24'te main'e ff-only alındı;
    PRIVACY_CONSENT §7). SM-A366B / Android 16,
    `368c60d` çalışma zamanıyla ayrı QA paketi, Google test kimlikleri, gerçek
    dokunuş, her coğrafya yolu yeni süreçte: yamalı AAR + üç JNI çağrısı çalıştı;
    #120 (`Setting debug geography to: 4` / `1`, geçersiz 0); NOT_EEA → NOT_REQUIRED
    + `canRequestAds` true + SDK + test reklamları; EEA → Google formu, form açıkken
    `canRequestAds` false + SDK init 0 + reklam yüklemesi 0, "Consent" → OBTAINED /
    true / REQUIRED → ancak sonra SDK; Ayarlar → "Gizlilik seçenekleri — Aç" →
    yerel `showPrivacyOptionsForm` → "Do not consent" → callback tam bir kez, SDK
    OBTAINED + true → yönetici SDK'yı izledi; "Gizlilik politikası" satırı gizli
    (URL yok); soğuk açılışta yeni oyuncu + EEA: tutorial ve tutorial'dan doğan
    Level 1 boyunca 0 rıza çağrısı / yuva 0 / geometri aynı, ilk güvenli kabukta
    (Harita) tam bir başlatma, sonra 4 kabuk geçişi + arka plan/öne dönüşte ikinci
    başlatma yok, tek AdView; logcat temiz (6 süreç). Tek değişiklik QA harness'ı
    (`tools/ads_device.gd` soğuk açılış seçeneği). Masaüstü regresyon yeşil,
    release kapısı yalnız OWNER/CONFIG. Kanıt: `build/qa_m9-01.1/A36_DEVICE_GATE.md`.
    İlk deneme (aynı gün, telefon adb'de görünmedi → BLOCKED): politika doküman düzeltmeleri (TFCD/TFUA
    kullanımdan kalktı → TFAT / `setAgeRestrictedTreatment`, GMA 25.3.0+; proje
    24.9.0'da, destek 2027-06-30 — kapalı test için engel değil, teknik borç;
    12 test kullanıcısı / 14 gün şartı yalnız 13 Kasım 2023 sonrası kişisel
    hesaplar için; 30 Eylül 2026 Android geliştirici doğrulaması yalnız ilk
    bölgesel dalga), QA harness `ump_raw` + gizlilik callback sayacı, QA paketi
    `48c9672` çalışma zamanıyla, **ek kanıt olarak emülatörde** (Android 16) yamalı
    AAR + üç JNI çağrısı + #120 + NOT_EEA + EEA formu + gizlilik seçenekleri formu
    + onboarding ertelemesi doğrulandı (logcat temiz; ek tarihçe — emülatör A36'nın
    yerine geçmedi). Notlar: `build/qa_m9-01.1/DEVICE_GATE_NOTES.md`.
- **Sırada: M8.6 — Visual Cohesion Rebuild** (ekranlar `UiKit`/`UiTokens`
  sistemine geçirilecek: ~~gameplay shell~~ ✅ → ~~home~~ ✅ → ~~map~~ ✅ →
  ~~shop~~ ✅ → ~~collection~~ ✅ main'de → ~~ikincil UI denetimi~~ ✅ →
  ~~M8.6-08 shell v2 + Ayarlar + Günlük~~ ✅ main'de → ~~M8.6-09 Round
  sonu~~ ✅ main'de → ~~M8.6-10 Devam/Refill~~ ✅ main'de (fd5dfab) →
  ~~M8.7-01 gameplay denetimi~~ ✅ dal `task/029` → ~~M8.7-02 gameplay
  cilası~~ ✅ dal `task/030`, A36 kapısı GEÇTİ, main'e merge izni
  bekliyor) → ~~M8.8-01 ses kaynak denetimi~~ ✅ dal `task/031` → ~~M8.8-02
  onaylı seslerin entegrasyonu~~ ✅ dal `task/032` → ~~M8.8-02.1 A36 cihaz
  kapısı~~ ✅ main'de (93aa25b) → ~~M8.9-01 AdMob temeli~~ ✅ → ~~M8.9-01.1 A36
  test-reklam kapısı~~ ✅ main'de (33b6382) → ~~M8.9-02 monetizasyon
  genişletmesi + günlük ödüller~~ ✅ + ~~02.1 birleşik günlük pencere~~ ✅ +
  ~~02.2 A36 cihaz kapısı~~ ✅ main'de (9561a4c) →
  ~~M8.10 ilk açılış tutorial'ı + ilk gün kuralı~~ ✅ + ~~M8.10.1 A36 cihaz
  kapısı~~ ✅ main'de (5a3a0f0) →
  ~~**M9-01** production release hazırlığı (kod)~~ ✅ + ~~M9-01.1 EEA/NOT_EEA
  A36 cihaz kapısı~~ ✅ main'de (A36 doğrulanmış ağaç `2fd8a72`, ff-only,
  2026-09-24) → owner kararları (paket kimliği, kitle, AdMob hesabı + kimlikler, upload
  anahtarı, gizlilik politikası) → yüklenebilir AAB → **M10 — Play kapalı test.** Analitik sağlayıcı
  (`AdEvents` / `TutorialEvents`) hâlâ ayrı karar.
  Ortam hazır (export template'leri, SDK,
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
- **fx doku adları içeriğin tersi (M8.7-01 ölçümü):** `fx_ring.png` DOLU
  parıltı, `fx_dot.png` İÇİ BOŞ halka. Gameplay yalnızca ROL sabitlerini
  kullanır (`GameBoard.GLOW_TEXTURE` / `RING_TEXTURE`, `PopEffect.DOT_TEXTURE`)
  ve bu dört Kenney ışık dokusunu toplamsal `fx_light_additive.tres` ile
  çizer; onaylı RewardGem/round_result dosyaları olduğu gibi (normal
  karışım) kullanır. PNG'leri yeniden adlandırma/düzenleme YOK
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
- **Ödüllü reklam sağlayıcısı BAĞLI (M8.9-01 ve M8.9-02 genişletmesi A36'da
  TEST reklamıyla doğrulandı):** `MonetizationManager`
  Main'e `set_rewarded_provider` ile takılıyor; Devam/Refill/GÜNLÜK ÖDÜLLER
  CTA'ları yalnız yüklü reklam varken aktif. **ÜRETİM ENGELLERİ:** ~~(A)
  eklenti UMP sarmalayıcı boşluğu~~ ve ~~(B) `debug_geography` #120~~ →
  **M9-01'de kodda kapandı** (yamalı AAR; EEA/NOT_EEA cihaz kapısı M9-01.1'de
  A36'da GEÇTİ, PRIVACY_CONSENT §7); (C) COPPA/TFCD/TFUA + kitle kararı (AUDIENCE_DECISION);
  (D) gerçek AdMob kimlikleri yok (App ID + rewarded + banner + interstitial);
  (E) kalıcı paket kimliği, upload anahtarı, gizlilik politikası URL'i. Release
  kapısı bunlar kapanmadan yüklenebilir AAB üretmez —
  docs/ANDROID_RELEASE_CHECKLIST.md.
- **Tipografi TAMAM (M8.5-09), production UI kabuğu TAMAM (M8.5-10):**
  bütün production ekranlar aynı font ailesinde ve aynı tasarım
  sisteminde (zemin/yüzey/kart/CTA/seçili/pasif katmanları, candy modal,
  ikonlu sekme çubuğu, ayarlar). Harita patikası M8.5-12'de geldi. Kalan
  görsel borç: skin renkleri (aşağıda).
- **Unity Asset Store paketi repoda DEĞİL:** `_visual_source/
  unity_free_casual_gui/` owner'ın makinesinde; EULA ham paketin yeniden
  dağıtımına izin vermeyebilir. Türetilmiş 14 ikon (`assets/visual/ui/icons/`)
  **M8.6-10'da üründen ve repodan kaldırıldı** (tek tüketici `UiPalette` idi);
  runtime yalnız LayerLab picto setini okuyor. Paketten türeyen dosya kalmadı.
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
**M9-01 / M9-01.1 main'e alındı (2026-09-24, ff-only; A36 doğrulanmış ağaç
`2fd8a72`) — M9-01 production release hazırlığı ve M9-01.1 UMP / gizlilik cihaz
kapısı KAPANDI.** Entegre main'de kapı yeniden yeşil, release kapısı yalnız
OWNER/CONFIG engelli (CODE 0). Ayrı iş: `task/037` (shell_shots düzeltmesi) bu
entegrasyondan sonra ele alınacak. Kalan yalnız owner/hesap kararları —
~~(a) `task/036` main kararı~~ ✅; (b) kalıcı paket kimliği; (c) kitle kararı
(AUDIENCE_DECISION §5); (d) Play Developer + AdMob hesapları, 3 reklam birimi,
GDPR mesajı → `[Release]` kimlikleri; (e) upload anahtarı (owner oluşturur,
checklist §4); (f) gizlilik politikası metni + barındırma → URL;
~~(g) EEA / NOT_EEA cihaz kapısı (PRIVACY_CONSENT §8)~~ ✅ M9-01.1; (h) mağaza
varlıkları. Tam liste: docs/ANDROID_RELEASE_CHECKLIST.md. Aşağıdaki eski liste
tarihseldir.

Owner/ChatGPT: (1) ~~`task/034` merge kararı~~ → **main'de (9561a4c)**;
M8.9-02 kapandı, kanıt `build/qa_m8.9-02.2/device/` (38 kare, notlar) +
`build/qa_m8.9-02_integration/`. Sıradaki karar başlıkları:
(2) eklenti UMP boşluğu kararı — küçük AAR yaması (3
sarmalayıcı + #120 `Number` düzeltmesi) mi, upstream PR mi (PRIVACY_CONSENT §4)
— üretim öncesi şart; (3) COPPA / hedef kitle kararı (PRIVACY_CONSENT §6); (4)
AdMob hesabı: uygulama kaydı, rewarded + banner + interstitial reklam birimi,
Privacy & messaging GDPR mesajı → `android_export.cfg [Release]`. (5)
~~M8.10 A36 cihaz kapısı + main entegrasyonu~~ → **GEÇTİ ve MAIN'E ALINDI**
(`3fb2945`, ff-only, 2026-09-22), owner görsel kontrolü PASS; **M8.10 KAPANDI,
ilk açılış deneyimi DONDURULDU** (`docs/TUTORIAL_SYSTEM.md` §12.1, kanıt
`build/qa_m8.10.1/`). Sonra analitik sağlayıcı
(`AdEvents` / `TutorialEvents` dikişine), ardından M9 Android export (adaptive icon,
`config/icon`, release keystore, Gradle preset her makinede).
Ayrıntılı liste: PROJECT_STATUS.md §8.
