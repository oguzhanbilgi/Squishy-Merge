# CLAUDE.md — Squishy Merge

Bu dosyayı her oturumun başında oku. Ardından şu sırayla oku:
1. `OWNER_WORKING_PROFILE.md` — owner'ın genel çalışma tarzı (tüm projelerde geçerli)
2. `PROJECT_CONTEXT.md` — bu projenin durumu, kapsamı, non-goals
3. `GAME_DESIGN.md` — kilitli oyun tasarımı spec'i

Bu üç dosya çakışırsa: owner'ın en son açık talimatı > PROJECT_CONTEXT.md >
GAME_DESIGN.md > OWNER_WORKING_PROFILE.md sırası geçerlidir.

## Çalışma disiplini (OWNER_WORKING_PROFILE'dan bu projeye özel çıkarımlar)

- Dar kapsam. GAME_DESIGN.md'de olmayan bir özelliği ekleme; eklemek
  istersen önce owner'a sor, sessizce scope genişletme.
- `git add .` KULLANMA. Değişen dosyaları açıkça isimlendirerek stage et.
- Force push yok. Local commit geçmişini yok etme.
- Bir milestone'u "bitti" diye işaretlemeden önce GAME_DESIGN.md §9'daki
  playtest checklist'i gerçekten çalıştır — çalıştırmadan "test edildi" deme.
- Final sanat/asset üretmeye ÇALIŞMA. Placeholder: düz renkli daire/kare
  (ColorRect veya basit çizilmiş Polygon2D), her tier farklı renk/boyut.
  Owner kendi asset'lerini hazır olunca Milestone 7'de entegre edecek.
- Otomatik test framework'ü (GUT vb.) KURMA — bu projenin ölçeğinde
  disproportionate overhead, bilinçli bir non-goal (PROJECT_CONTEXT.md'de
  yazılı). Onun yerine manuel checklist kullan.
- Her milestone sonunda owner'a KISA bir özet ver (ne yapıldı, ne test
  edildi, sıradaki adım) — milestone başına devasa rapor yazma.

## GDScript stil kuralları
- snake_case fonksiyon/değişken, PascalCase class/scene isimleri
- Mümkün olan yerde static typing kullan (`var score: int = 0`)
- Polling yerine signal kullan (örn. merge event'i bir signal ile yayılsın,
  UI ona subscribe olsun)
- Global state için sadece gerekli olan yerde Autoload/singleton kullan:
  önerilen üç autoload: `GameState`, `AudioManager`, `SaveManager`. Bundan
  fazla autoload eklemeden önce gerekçelendir.
- Level verisi: `Resource` (`.tres`) tabanlı, kod değişmeden yeni level
  eklenebilmeli.

## Git iş akışı
- Her milestone = en az bir commit. Commit mesajı formatı:
  `[M<no>] <kısa açıklama>` — örn. `[M1] Core merge fiziği ve tier spawn`
- `main` branch üzerinde direkt çalışılabilir (tek geliştiricili, hızlı
  iterasyon — burada PR/branch overhead'i gerekmiyor).

## Devlog
Her milestone bitince `DEVLOG.md`'ye TEK satırlık bir giriş ekle:
tarih, milestone no, ne tamamlandı, varsa blokaj. Milestone başına bir
paragraflık dev raporu YAZMA — bu bilinçli olarak minimal tutuluyor.

## Ortam doğrulama (Milestone 0 — ilk çalıştırmada mutlaka yap)
Aşağıdakileri kontrol et ve sonucu owner'a raporla, eksik olan varsa kurulum
adımlarını öner (kurma, sadece raporla — owner onaylamadan sistem geneli
kurulum yapma):
```
godot --version          # 4.7.x bekleniyor
echo %ANDROID_HOME%      # veya $ANDROID_HOME (platforma göre)
java -version            # Android export için JDK gerekli
```
Godot Editor içinde: Editor → Export → Android export template'lerinin
kurulu olup olmadığını kontrol et (Editor Settings → Export → Android).
Keystore yoksa (debug/release), owner ile birlikte oluştur — keystore
şifresini asla dosyaya/commit'e yazma, sadece owner'ın yerel makinesinde
tutulmasını söyle.

## Non-goals hatırlatması
PROJECT_CONTEXT.md §Non-goals'ı tekrar oku. Özellikle: IAP yok, reklam yok,
çoklu tema yok, backend yok, iOS yok. Bunlardan biri "iyi fikir" gibi
görünse bile v1 kapsamına ekleme.
