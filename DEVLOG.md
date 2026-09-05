# DEVLOG.md

Milestone başına tek satır. Format: `- YYYY-MM-DD [M<no>] <özet> — blokaj: <varsa>`

- 2026-09-05 [M0] Ortam doğrulandı (Godot 4.6.3, Android SDK var, export template + debug keystore YOK), proje iskeleti kuruldu: klasör yapısı, main.tscn, 3 autoload (GameState/AudioManager/SaveManager), mobil portrait ayarları — blokaj: Godot sürümü dokümandaki 4.7.2 değil 4.6.3; export template ve debug keystore kurulu değil (M9 öncesi gerekli)
- 2026-09-05 [M0] Export template'leri (4.6.3.stable) kuruldu, debug keystore oluşturuldu, doküman sürüm referansları 4.6.3-stable'a düzeltildi — blokaj: yok
- 2026-09-05 [M1] Core fizik + merge: 8 tier config, RigidBody2D dumpling, drag-drop kontrolü, merge + squash-stretch + pop efekti, tier 8 kutlaması, 1.5sn taşma fail state — blokaj: merge puan formülü GAME_DESIGN'da tanımlı değil, geçici değerler kullanıldı
- 2026-09-05 [M1] Kap geometrisi ölçümle ayarlandı (oynanabilir yükseklik 880 -> 400 px, ~11-12 tier 5 ile taşma), OWNER_WORKING_PROFILE.md gitignore'landı, merge puan tablosu GAME_DESIGN'da geçici olarak işaretlendi — blokaj: tier yarıçapları kap genişliğine göre küçük, M2 level dengesinde gözden geçirilmeli
- 2026-09-05 [M1] Fizik hissi: çarpma bazlı squash-stretch (hıza orantılı 0.05-0.2 sapma, 120ms, 130ms debounce), bounce 0.05->0.12, linear_damp 0.15 replace, serbest dönüş doğrulandı — blokaj: owner F5 playtest onayı bekleniyor
- 2026-09-05 [M1] Squash genliği 0.08-0.25'e çıkarıldı, duvar/tabana da PhysicsMaterial verildi (sekme 0.13, efektif ~0.24, ölçümle seçildi) — blokaj: owner F5 playtest onayı bekleniyor
- 2026-09-05 [M2] Level sistemi data-driven (.tres, klasör taramalı LevelLibrary), 10 level + sonsuz mod, level seçim/sonuç ekranları, kap genişlikleri ölçümle (600/540/480/420/370), merge puan tablosu balans pasıyla kilitlendi (50/70/90/110/130/150/200) — blokaj: level 10'un en dar kapta gerçekten bitirilebildiği insan playtest'iyle doğrulanmadı
