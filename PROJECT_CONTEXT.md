# PROJECT_CONTEXT.md — Squishy Merge

## Product
Fizik tabanlı (Suika Game / watermelon-game tarzı) squishy dumpling birleştirme
mobil oyunu. Üstten kaba düşen dumpling'ler aynı tier'da çarpışınca birleşip bir
üst tier'a evriliyor. 10 sabit level + level 10 sonrası açılan sonsuz mod.
Tema: sevimli/kawaii squishy dumpling karakterleri, ASMR/rahatlatıcı his.

## User
Casual mobil oyun oynayan geniş kitle; özellikle merge/idle/ASMR-cozy oyun
sevenler. Kısa oturumlarla (30–90 sn round) oynamayı tercih eden kullanıcı.

## Core problem
Mevcut merge oyunlarının çoğu ya karmaşık grid-tabanlı sistemler (çok fazla UI/
kural) ya da zayıf duyusal geri bildirim sunuyor. Squishy Merge basit fizik +
güçlü duyusal tatmin (squash-stretch animasyon, escalating ses, combo efekti) +
net, kısa level ilerlemesi ile bu boşluğu hedefliyor.

## Business model
- v1: reklamsız, IAP yok. Amaç: organik/ASO testi, gerçek retention verisi
  toplamak.
- v1'de **oyun içi mağaza VAR** (M8): Hamur ile kozmetik skin satın alınıyor.
  Gerçek para geçmiyor — bu bir soft-currency sink'i, IAP değil.
  Bkz. GAME_DESIGN §5.6.
- v1.1+ (şimdi YAPILMIYOR): ödüllü reklam (ekstra sandık için), muhtemel
  kozmetik IAP (skin paketleri — gerçek parayla). Gerçek kullanıcı verisi
  olmadan bu katmana zaman harcamıyoruz.

## Success metric
v1 için "başarı" = Play Console'da (kapalı test track'inde) canlı, crash'siz,
tam oynanabilir bir build. Ticari/growth kararları v1.1'de gerçek kullanıcı
verisiyle alınacak — şimdi tahmin/vaat yok.

## Non-goals (v1 — bilinçli olarak YAPILMIYOR)
- Çoklu kavanoz/tema seçeneği (tek sabit tema)
- IAP, reklam, herhangi bir ödeme entegrasyonu
- Haptic feedback (v1.1'e bırakıldı)
- Leaderboard, bulut kayıt, hesap sistemi, backend/sunucu
- Otomatik test framework'ü (GUT vb.) — bu ölçekte disproportionate overhead;
  manuel playtest checklist kullanılacak
- iOS build
- Final/prodüksiyon kalitesinde sanat (owner kendi asset'lerini
  sağlayacak; Claude Code placeholder geometrik şekillerle çalışır)

## Stack
- Godot 4.6.3 (stable), GDScript
- Android export → Google Play (Play App Signing, AAB format)
- Yerel repo: makineye göre değişir (ev: C:\dev\squishy-merge, iş:
  D:\dev\squishy-merge) — sabit yol varsayma.
- GitHub: https://github.com/oguzhanbilgi/Squishy-Merge (şu an boş)

## Canonical repo state
main branch henüz yok. İlk commit bu paketle (PROJECT_CONTEXT.md,
GAME_DESIGN.md, CLAUDE.md, README.md, .gitignore) + proje iskeletiyle atılacak.

## Current task
Milestone 0: ortam doğrulama + proje iskeleti kurulumu (bkz. CLAUDE.md
milestone tablosu).

## Quality gates
- Her milestone sonunda GAME_DESIGN.md'deki manuel playtest checklist'i geçmeli
- Export alınan APK/AAB gerçek cihaz veya emulator'de crash vermeden açılmalı
- `git add .` kullanılmayacak — dosyalar açıkça sahnelenecek (staged)
- Force push yok, local iş üzerine yazılmayacak

## Project-specific invariants
- Tier sayısı sabit: 8 (bkz. GAME_DESIGN.md)
- Level sayısı v1: 10 + level 10 sonrası sonsuz mod
- Sandık rarity oranları: Common %60 / Rare %25 / Epic %12 / Legendary %3
- Görsel asset üretimi owner'da — Claude Code final art üretmeye ÇALIŞMAZ

## Current blockers
- Yeni Google Play Developer hesabı henüz açılmadı / kimlik doğrulaması
  bekliyor (owner tarafından paralel başlatılmalı — bu repo işiyle ilgisiz)
- Android SDK / JDK / Godot export template kurulum durumu doğrulanmadı

## M9 için hatırlatmalar
- **`tools/` klasörü export preset'inde filtrelenmeli.** Buradaki script'ler
  (bot_runner, bot_brain, screenshot_runner, make_fx_sprites, tier_geometry,
  star_thresholds, make_placeholder_sprites + .tscn'leri) yalnızca geliştirme
  araçları; oyun çalışırken hiçbiri kullanılmıyor. Filtre yoksa APK/AAB'ye
  gereksiz yere dahil oluyorlar. Export preset'inde
  `exclude_filter` alanına `tools/*` eklenmesi yeterli.
  (M8'de fark edildi, uygulanmadı — export preset'i M9'da oluşturulacak ve
  `export_presets.cfg` zaten gitignore'lu.)

## Next action
Milestone 0'ı başlat: ortam doğrulama + proje iskeleti.
