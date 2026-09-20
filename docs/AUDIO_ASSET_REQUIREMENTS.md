# AUDIO_ASSET_REQUIREMENTS.md — SFX şartnamesi (M8.5-15; M8.8-02'de KARŞILANDI)

> **DURUM (M8.8-02): şartname karşılandı.** Final örnekler owner onayıyla
> entegre edildi; production gerçeği `docs/audio/AUDIO_SYSTEM.md`,
> `docs/audio/MERGE_SOUND_FAMILY.md`, `docs/audio/HAPTIC_MAPPING.md`, dosya
> manifesti `docs/audio/PRODUCTION_FILES.md`, kaynaklar `assets/audio/CREDITS.md`.
> **Aşağıdaki hedef dosya adları ESKİDİ** (production adları `sfx_merge_body_light_01`,
> `sfx_tier8_bloom_01`, `sfx_ui_confirm_01` … — tam liste manifestte). "Aynı adla
> üzerine yaz" iş akışı da kalktı: yeni bir örnek eklemek = `tools/audio_production_build.py`
> `RECIPES`'e satır + `AudioManager.EVENTS`'e yol. Format kuralları (aşağıdaki "Ortak
> kurallar") hâlâ geçerlidir ve build betiği bunları uygular; Sonniss GDC kaynakları
> (royalty-free, atıfsız, AI kullanımı yasak) M8.8-01'de lisans doğrulamasıyla
> havuza eklendi. Gerisi tarihçe.

Orijinal (M8.5-15): Ses SİSTEMİ hazır; final ÖRNEKLER eksik. Bu liste, ses sistemine
dokunmadan kaynak bulmak / ürettirmek için yeterli olacak şekilde yazıldı.
**Dosyayı aynı adla `assets/audio/sfx/<klasör>/` altına koy, Godot'ta bir
kez import et — kod değişmez.** Varyant eklemek istersen
`AudioManager.EVENTS[...]["streams"]` listesine yolu ekle (tek satır).

Ortak kurallar:
- Format: **WAV 44.1 kHz 16-bit mono** (kısa SFX; QOA/OGG'ye gerek yok,
  import `compress/mode=0`). 1 sn üstü jingle'lar OGG olabilir.
- Loop yok. Baş sessizliği ≤ 5 ms, kuyruk ≤ 80 ms, tık yok (fade).
- Tepe **−3 … −6 dBFS** (normalize ETME; mix seviyeleri `gain_db`'de).
- Karakter: candy / kawaii / squishy. **Sert transient, bas-ağır darbe,
  metalik çınlama, 8-bit/chiptune, gerçekçi patlama YOK.** Telefon
  hoparlöründe (~300 Hz altı yok) okunmalı.
- Lisans: CC0, owner'ın kendi üretimi ya da (M8.8-01'den itibaren) lisansı
  doğrulanmış Sonniss GDC bundle dosyası; kaynağı `assets/audio/CREDITS.md`'ye yaz.
- Import: `.import` dosyasında `compress/mode=0` (PCM) — Godot 4.6 varsayılanı QOA'dır
  (M8.8-02'de düzeltildi).

Öncelik: ★★★ imza / her round, ★★ sık, ★ nadir.

| ★ | olay | hedef dosya | süre | karakter | frekans | varyant | interim durumu |
|---|---|---|---|---|---|---|---|
| ★★★ | merge | `gameplay/sfx_merge_pop_01..03.wav` | 0.15–0.30 s | yumuşak squish + candy pop; sulu, hafif "blup"; tier pitch'i kodda (0.85→1.48×) → örnek nötr, 1.0×'de doğal | 300–3 kHz, hafif pes gövde | 3–4 | sentez (sinüs pop + 190 Hz gövde) |
| ★★★ | iniş | `gameplay/sfx_land_soft_01..03.wav` **(yeni ad; kod şu an `kenney_impact_soft_01.ogg` kullanıyor — dosyayı ekleyip `land` ve `merge_body` listesine yaz)** | 0.08–0.18 s | yumuşak hamur "puf/thud", darbe değil; pitch kodda tier'a göre 1.25→0.78× | 150–1.5 kHz | 3 | Kenney impactSoft (KEEP adayı) |
| ★★★ | bırakma | `gameplay/sfx_drop_01..03.wav` | 0.06–0.12 s | havadar mini "plop", sessiz; her 0.4 sn'de bir çalıyor, asla rahatsız etmemeli | 300–1 kHz | 3 | sentez |
| ★★★ | UI dokunuş | `ui/sfx_ui_tap_01.wav` | 0.03–0.06 s | yumuşak candy "tık", tek aile; rastgelelik yok | 800–2 kHz | 1 | sentez |
| ★★ | sekme | `ui/sfx_ui_tab_01.wav` | 0.03–0.05 s | dokunuştan hafif ve tiz | 1–2.5 kHz | 1 | sentez |
| ★★ | pencere aç / kapat | `ui/sfx_ui_modal_open_01.wav`, `ui/sfx_ui_modal_close_01.wav` | 0.10–0.18 s | yumuşak pop + minik whoosh; kapanış aynısının aşağı yönlüsü, daha kısa | 300–2.5 kHz | 1+1 | sentez |
| ★★ | combo | `rewards/sfx_sparkle_up_01.wav` (paylaşımlı, bkz. aşağı) | 0.3–0.5 s | hafif çan/candy parıltı arpeji, YUKARI; bağırma/arcade yok; pitch kodda x2…x8'de +4 %/adım | 1–4 kHz | 1–2 | sentez arpej C6-E6-G6-C7 |
| ★★ | yüksek tier merge katmanı (6–7) | aynı `sfx_sparkle_up_01` (ayrı istenirse `rewards/sfx_merge_high_01.wav` ekle) | 0.3–0.5 s | merge pop'un üstüne kısa parıltı | 1–4 kHz | 1 | sentez |
| ★★ | Tier 7 → 8 kutlama | `rewards/sfx_sparkle_big_01.wav` | 0.7–1.2 s | premium katmanlı parıltı + çan, kısa; normal merge'den açıkça özel; fanfar değil | 500 Hz–5 kHz | 1 | sentez 6 nota + akor |
| ★★ | tehlike tik'i | `gameplay/sfx_danger_soft_01.wav` | 0.2–0.35 s | pes, yumuşak iki notalı uyarı; 0.5 s'de bir tekrar eder → siren/alarm hissi YASAK | 200–600 Hz | 1–2 | sentez |
| ★★ | taşma (fail anı) | `gameplay/sfx_fail_soft_01.wav` | 0.5–0.9 s | yumuşak, inen, "hayır ya" candy tonu; buzzer değil | 300–800 Hz | 1 | sentez 3 nota |
| ★★ | round kaybı | `gameplay/kenney_jingle_lose_01.ogg` → istenirse `gameplay/sfx_round_lose_01.wav` | 0.4–0.8 s | kısa hüzünlü ama sevimli iniş | — | 1 | Kenney PIZZI16 (KEEP adayı, owner dinlesin) |
| ★★ | round kazanma | `rewards/kenney_jingle_win_01.ogg` → istenirse `rewards/sfx_round_win_01.wav` | 0.8–1.5 s | neşeli kısa tamamlama sting'i | — | 1 | Kenney PIZZI07 (KEEP adayı) |
| ★★ | devam (revive) | `gameplay/sfx_revive_01.wav` | 0.5–0.8 s | yükselen toparlanma parıltısı / whoosh, ödülden farklı | 400 Hz–4 kHz | 1 | sentez |
| ★★ | bomba whoosh | `powers/sfx_whoosh_01.wav` | 0.25–0.35 s (uçuş 0.28 s) | yumuşak hava sesi, mermi düşerken | süzülmüş gürültü 300–2.5 kHz | 1 | sentez (gürültü süpürme) |
| ★★ | bomba vuruşu | `powers/sfx_bomb_impact_01.wav` | 0.2–0.35 s | sevimli, tok, kompakt "pop-bum"; gerçekçi/bas-ağır değil | 150 Hz–3 kHz | 1–2 | sentez |
| ★★ | büyütücü | `powers/sfx_upgrade_01.wav` | 0.4–0.6 s | sihirli yükseliş + shimmer, kısa premium | 400 Hz–5 kHz | 1 | sentez |
| ★★ | sarsıntı | `powers/sfx_shake_01.wav` | 0.3–0.4 s | jöle titremesi / wobble; sert pes vibrasyon değil, telefon hoparlöründe hoş kalmalı | 120–600 Hz + hafif gürültü | 1 | sentez 140 Hz wobble |
| ★★ | temizleyici puf | `powers/sfx_puff_01..02.wav` | 0.06–0.12 s | hafif hava "puf"; 20 kez art arda çalabilir → yumuşak, tiz değil | 300–1.5 kHz | 2 | sentez |
| ★ | güç seçimi | `ui/kenney_pluck_01.ogg` → istenirse `ui/sfx_power_arm_01.wav` | 0.08–0.15 s | hafif "hazır" tık/pluck | 500 Hz–2 kHz | 1 | Kenney pluck (KEEP adayı) |
| ★ | satın alma / refill | `rewards/sfx_reward_chime_01.wav` | 0.4–0.6 s | küçük premium coin/ding-ding | 1–4 kHz | 1 | sentez |
| ★ | yetersiz Hamur | `ui/sfx_ui_invalid_01.wav` | 0.12–0.2 s | ölçülü, pes "bonk"; sert hata buzzer'ı YOK | 150–500 Hz | 1 | sentez |
| ★ | skin tak | `rewards/sfx_sparkle_up_01.wav` (paylaşımlı) → istenirse `ui/sfx_equip_01.wav` | 0.2–0.4 s | şık mini parıltı/pop | 1–4 kHz | 1 | sentez |
| ★ | sandık açılış aşaması | `rewards/kenney_open_01.ogg` → istenirse `rewards/sfx_chest_open_01.wav` | 0.15–0.3 s | kapak/kilit açılma beklentisi | — | 1 | Kenney open_001 (KEEP adayı) |
| ★ | ödül Common | `gameplay/sfx_merge_pop_02.wav` (paylaşımlı) → istenirse `rewards/sfx_reward_common_01.wav` | 0.15–0.3 s | basit tatmin edici pop | — | 1 | sentez |
| ★ | ödül Rare | `rewards/sfx_sparkle_up_01.wav` → istenirse `rewards/sfx_reward_rare_01.wav` | 0.3–0.5 s | biraz daha zengin parıltı | — | 1 | sentez |
| ★ | ödül Epic | sparkle_up + chime katmanı → istenirse `rewards/sfx_reward_epic_01.wav` | 0.5–0.8 s | premium parıltı + çan | — | 1 | sentez katman |
| ★ | ödül Legendary | `rewards/sfx_sparkle_big_01.wav` → istenirse `rewards/sfx_reward_legendary_01.wav` | 0.8–1.2 s | en güçlü, kısa, parlak; 5 sn fanfar YOK | — | 1 | sentez |
| ★ | günlük ödül | `rewards/sfx_reward_chime_01.wav` (paylaşımlı, 0.95×) | 0.4–0.6 s | neşeli ödül cue'su | — | 1 | sentez |
| ★ | level açıldı | `rewards/sfx_sparkle_up_01.wav` (1.05×) → istenirse `rewards/sfx_level_unlock_01.wav` | 0.3–0.5 s | hafif unlock parıltısı | — | 1 | sentez |
| ★ | yıldız reveal | `ui/kenney_pluck_01.ogg` (pitch +12 %/yıldız) | 0.1–0.2 s | "pat" — kısa, sıcak | — | 1 | Kenney pluck (KEEP adayı) |
| ★ | anahtar açıldı | `ui/kenney_pluck_01.ogg` (1.2×) | 0.1–0.2 s | onay pluck'ı | — | 1 | Kenney pluck |

"İstenirse ... ekle" satırları: şu an başka bir olayın dosyasını paylaşan
olaylar. Ayrı örnek gelirse `EVENTS` satırındaki `streams` yolunu değiştir.

## Müzik

Bilinçli olarak YOK (GAME_DESIGN §6, PROJECT_CONTEXT non-goal). Music bus
yapıda boş duruyor; Ayarlar'da müzik anahtarı yok. Gerçek bir loop gelirse:
`assets/audio/music/`, bus `Music`, `AudioManager`'a `play_music()` +
ayar satırı — bu tur kapsamı dışı.
