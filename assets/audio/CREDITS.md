# assets/audio — ses asset'leri, kaynakları ve lisansları (M8.8-02 production seti)

Runtime yalnızca `sfx/**` altını okur; eşleme `AudioManager.EVENTS`
(`scripts/autoload/audio_manager.gd`). Olay haritası, bus, seviye, öncelik:
`docs/audio/AUDIO_SYSTEM.md`. Merge ailesi: `docs/audio/MERGE_SOUND_FAMILY.md`.
Titreşim: `docs/audio/HAPTIC_MAPPING.md`. Her dosyanın ölçülmüş işleme ayrıntısı
(trim, filtre, fade, tepe/RMS/süre, telefon bandı payı): `docs/audio/PRODUCTION_FILES.md`
(üretici: `tools/audio_production_build.py`). Lisans metinleri: `docs/licenses/audio/`.

Bütün dosyalar **owner'ın dinleyip onayladığı** (M8.8-01.1 kısa listesi) ya da owner'ın
o kategoride hiçbir adayı beğenmemesi üzerine aynı havuzdan seçilen (Sarsıntı, tehlike,
Legendary) kaynaklardan **bir kez** üretildi: WAV 44.1 kHz 16-bit mono, loop yok, baş
sessizliği ≤ 1 ms, tepe −4 dBFS (merge POP varyantları RMS eşitlemesi için −6.5 / −3.0).
Orijinal kaynak kütüphanesi repo DIŞINDA (`D:\dev\squishy-audio-source`, gitignore'lu
`_audio_source/` değil); repoya hiçbir orijinal paket, kısa liste ya da dinleme kopyası
girmedi.

## Klasörler

```
sfx/ui/        dokunuş, onay, geri, hata (tek Kenney Interface ailesi)
sfx/gameplay/  bırakma/iniş, merge POP + üç gövde havuzu + parıltı + çan, tehlike, round kaybı
sfx/powers/    bomba (fırlatma/vuruş/puf), büyütücü (yükseliş/hava), sarsıntı, temizleyici
sfx/rewards/   tier 8 bloom/kutu/kuyruk, round kazanma, sandık, Hamur ödülü
```

## Lisanslar

### Kenney.nl — CC0 1.0 (Creative Commons Zero)

Paketlerin kendi `License.txt` dosyalarından (kopyaları `docs/licenses/audio/`):
"This content is free to use in personal, educational and commercial projects.
Support us by crediting Kenney or www.kenney.nl (this is not mandatory)". Atıf
zorunlu değil; bu dosya yine de kaynağı belirtir.
Paketler: Impact Sounds 1.0 (19-12-2019) — https://kenney.nl/assets/impact-sounds ·
Interface Sounds 1.0 (11-02-2020) — https://kenney.nl/assets/interface-sounds ·
Music Jingles — https://kenney.nl/assets/music-jingles

### Sonniss — #GameAudioGDC Bundle 2026 (Part 9), royalty-free EULA

`Sonniss.com-GDC2026-GameAudioBundle*.zip` içindeki `License - GDC Game Audio.pdf`
(kopyası `docs/licenses/audio/sonniss_GDC2026_License.pdf`) ve `Readme.txt`:
- Dünya çapında, münhasır olmayan, **royalty-free** lisans; sınırsız proje, ömür boyu.
- Kişisel ve ticari projelerde **atıf gerekmeden** kullanma ve **değiştirme** hakkı;
  oyun / film / etkileşimli işlerle senkronize etme hakkı.
- Kısıtlar: orijinal kaydın yazarlığını üstlenmek amacıyla değiştirmek yasak; sesleri
  "oldukları gibi" tek başına satmak yasak (projeye gömülü satış serbest).
- **"NO AI TRAINING OR USAGE"**: sesler yapay zekâ eğitimi/geliştirmesi için
  kullanılamaz, bu hak alt lisanslanamaz. Bu projede dosyalar yalnızca ölçüldü,
  kırpıldı, süzüldü ve oyuna gömüldü; hiçbir üretken ses aracına verilmedi —
  verilmemeli.
- Telif hakkı ilgili tedarikçide kalır; Sonniss lisanslama yetkisini garanti eder.
Bu bundle'dan kullanılan tedarikçiler / kütüphaneler: Cinematic Sound Design (Cartoon &
Animation Vol 2, Cartoon Impacts, UI Interaction Elements, Ultra Transitions & Impacts,
User Interface), Sonic Bat (Music Boxes), Epic Stock Media (HD Lock And Mechanism
Sound Design Kit).

## Production dosyaları — kaynak, işleme, sonuç

İşleme zinciri (hepsinde ortak): mono indirgeme (kanal ortalaması) → 44.1 kHz'e
pencereli-sinc yeniden örnekleme (bir kez) → en fazla bir 2. derece yüksek geçiren + bir
alçak geçiren süzgeç → baş kırpma (≤ 1 ms) → kuyruk kırpma (−54 dBFS + 30 ms) → 2 ms
giriş fade'i + belirtilen çıkış fade'i → tepe −4 dBFS → 16-bit TPDF dither.
"Trim" kaynak zaman çizelgesindeki kesittir.

### Kenney Impact Sounds 1.0 — CC0

| orijinal dosya | işleme | production dosyası | kullanım |
|---|---|---|---|
| `impactGeneric_light_002.ogg` | HP 100 Hz, fade 20 ms | `sfx/gameplay/sfx_merge_body_light_01.wav` | merge gövdesi T1–T3 |
| `impactGeneric_light_004.ogg` | HP 100 Hz, fade 20 ms | `sfx/gameplay/sfx_merge_body_light_02.wav` | merge gövdesi T1–T3 (varyant) |
| `impactPlate_light_003.ogg` | trim 0–0.35 s, HP 120 Hz, fade 60 ms | `sfx/gameplay/sfx_merge_body_full_01.wav` | merge gövdesi T4–T6 |
| `impactPlate_medium_001.ogg` | trim 0–0.35 s, HP 120 Hz, fade 60 ms | `sfx/gameplay/sfx_merge_body_full_02.wav` | merge gövdesi T4–T6 (varyant) |
| `impactPunch_medium_001.ogg` | trim 0–0.40 s, HP 110 Hz, LP 6 kHz, fade 60 ms | `sfx/gameplay/sfx_merge_body_large_01.wav` | merge gövdesi T7–T8, sonsuz yok oluşu |
| `impactGlass_light_002.ogg` | LP 8 kHz, fade 30 ms | `sfx/gameplay/sfx_merge_sparkle_01.wav` | merge parıltısı T3+, combo, yıldız reveal |
| `impactGlass_light_000.ogg` | LP 8 kHz, fade 30 ms | `sfx/gameplay/sfx_merge_sparkle_02.wav` | parıltı varyantı |
| `impactGlass_light_004.ogg` | LP 8 kHz, fade 30 ms | `sfx/gameplay/sfx_merge_sparkle_03.wav` | parıltı varyantı |
| `impactBell_heavy_002.ogg` | trim 0–0.50 s, HP 150 Hz, fade 80 ms | `sfx/gameplay/sfx_merge_chime_01.wav` | merge çanı T5–T7 |
| `impactBell_heavy_000.ogg` | trim 0–1.10 s, HP 150 Hz, fade 120 ms | `sfx/rewards/sfx_tier8_bloom_01.wav` | tier 8 bloom'u, Legendary |
| `impactGeneric_light_001.ogg` | HP 120 Hz, fade 20 ms | `sfx/gameplay/sfx_land_01.wav` | iniş (`land`) + bırakma tik'i (`drop`, 1.35×) |
| `impactPunch_medium_000.ogg` | trim 0–0.40 s, HP 110 Hz, fade 60 ms | `sfx/powers/sfx_bomb_impact_01.wav` | bomba vuruşu |
| `footstep_snow_000.ogg` | trim 0–0.30 s, HP 150 Hz, LP 7 kHz, fade 60 ms | `sfx/powers/sfx_bomb_poof_01.wav` | bomba pufu (+15 ms) |
| `impactWood_light_001.ogg` | trim 0–0.09 s, HP 150 Hz, LP 6 kHz, fade 25 ms | `sfx/gameplay/sfx_danger_01.wav` | tehlike tik'i |
| `impactWood_light_003.ogg` | trim 0–0.09 s, HP 150 Hz, LP 6 kHz, fade 25 ms | `sfx/gameplay/sfx_danger_02.wav` | tehlike tik'i (varyant) |

### Kenney Interface Sounds 1.0 — CC0

| orijinal dosya | işleme | production dosyası | kullanım |
|---|---|---|---|
| `select_002.ogg` | fade 10 ms | `sfx/ui/sfx_ui_tap_01.wav` | `ui_tap`, `ui_tab` (1.15×), `ui_select` (0.9×) |
| `confirmation_001.ogg` | fade 40 ms | `sfx/ui/sfx_ui_confirm_01.wav` | `ui_purchase`, `ui_toggle_on` (1.2×), `ui_equip` (1.1×), `ui_modal_open` (0.95×), `power_arm` (1.15×) |
| `back_002.ogg` | fade 15 ms | `sfx/ui/sfx_ui_back_01.wav` | `ui_modal_close` |
| `error_008.ogg` | fade 30 ms | `sfx/ui/sfx_ui_error_01.wav` | `ui_invalid` |
| `minimize_006.ogg` | fade 30 ms | `sfx/powers/sfx_bomb_launch_01.wav` | bomba fırlatma (`bomb_whoosh`) |
| `maximize_006.ogg` | fade 30 ms | `sfx/powers/sfx_upgrade_charge_01.wav` | büyütücü dokunuşu (`upgrade`) |

### Kenney Music Jingles — CC0

| orijinal dosya | işleme | production dosyası | kullanım |
|---|---|---|---|
| `Steel jingles/jingles_STEEL09.ogg` | fade 60 ms | `sfx/rewards/sfx_round_win_01.wav` | round kazanma; devam (0.9×) |
| `Pizzicato jingles/jingles_PIZZI00.ogg` | fade 60 ms | `sfx/gameplay/sfx_round_lose_01.wav` | round kaybı; taşma anı (`fail`, 0.94×) |

### Sonniss GDC 2026 Part 9 — royalty-free, atıfsız

| orijinal dosya (kütüphane · tedarikçi) | işleme | production dosyası | kullanım |
|---|---|---|---|
| `Cartoon Bubbles Short.wav` (Cartoon & Animation Vol 2 · Cinematic Sound Design) | trim 0–0.200 s, HP 120 Hz, fade 30 ms, tepe −6.5 dBFS | `sfx/gameplay/sfx_merge_pop_01.wav` | merge POP çekirdeği |
| aynı dosya, ikinci kabarcık | trim 0.215–0.500 s, HP 120 Hz, fade 40 ms, tepe −3.0 dBFS | `sfx/gameplay/sfx_merge_pop_02.wav` | merge POP varyantı |
| `SBmb_Music Box A 013.wav` (Music Boxes · Sonic Bat) | trim 0–0.55 s (ilk nota), LP 10 kHz, fade 150 ms | `sfx/rewards/sfx_tier8_box_01.wav` | tier 8 müzik kutusu notası, Epic/Legendary |
| `Button Arp Twinkle.wav` (User Interface · Cinematic Sound Design) | trim 0–0.60 s, LP 8 kHz, fade 100 ms | `sfx/rewards/sfx_tier8_tail_01.wav` | tier 8 kuyruğu, Rare/Epic/Legendary, level açılışı |
| `Woosh Sweep Slide Infographics Basic.wav` (Ultra Transitions & Impacts · Cinematic Sound Design) | trim 0–0.30 s, HP 200 Hz, LP 9 kHz, fade 60 ms | `sfx/powers/sfx_upgrade_air_01.wav` | büyütücü dönüşümü (`upgrade_transform`) |
| `Accept Boing Crunch.wav` (UI Interaction Elements · Cinematic Sound Design) | trim 0.015–0.470 s (son 1.5 kHz "accept" pingi kesildi), HP 150 Hz, LP 7 kHz, fade 8 / 70 ms | `sfx/powers/sfx_shake_01.wav` | sarsıntı (jöle titremesi) |
| `Cartoon Pull Swoosh Readout.wav` (Cartoon & Animation Vol 2 · Cinematic Sound Design) | trim 0.060–0.420 s, HP 300 Hz, LP 9 kHz, fade 10 / 80 ms | `sfx/powers/sfx_clear_sweep_01.wav` | temizleyici süpürmesi (altta) |
| `Cartoon Pops Random Sequence Reverb.wav` (Cartoon Impacts · Cinematic Sound Design) | üç kuru pop dilimi: 0.003–0.048 / 0.073–0.135 / 0.148–0.195 s, HP 150 Hz, LP 9 kHz, fade 8–10 ms | `sfx/powers/sfx_clear_pop_01/02/03.wav` | temizleyici parça başına pop |
| `MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav` (HD Lock And Mechanism Sound Design Kit · Epic Stock Media) | trim 0–0.35 s (etkin 0.14 s), HP 120 Hz, LP 10 kHz, fade 50 ms | `sfx/rewards/sfx_chest_open_01.wav` | sandık açılışı |
| `Ting Coins.wav` (UI Interaction Elements · Cinematic Sound Design) | trim 0–0.70 s, HP 150 Hz, LP 10 kHz, fade 100 ms | `sfx/rewards/sfx_reward_dough_01.wav` | Hamur / Common ödülü, günlük ödül (0.95×) |

## M8.8-02'de kaldırılanlar

M8.5-15 interim seti tamamen kalktı: 22 sentez `sfx_*.wav` (`tools/make_sfx.gd`,
üretici de silindi — yeniden çalıştırılsa production adlarının üstüne yazardı) ve
5 Kenney OGG (`kenney_impact_soft_01`, `kenney_pluck_01`, `kenney_open_01`,
`kenney_jingle_win_01`, `kenney_jingle_lose_01`). Hepsi git geçmişinde (`0abd22b`).

## Yeniden üretme / değiştirme

```
D:\dev\squishy-audio-source\.venv\Scripts\python.exe tools/audio_production_build.py
godot --headless --path . --import
godot --headless --audio-driver Dummy --path . res://tools/audio_test.tscn
```

Build deterministiktir (sabit dither tohumu): aynı kaynak + aynı reçete = bayt bayt aynı
dosya. Yeni bir kaynak eklemek = `RECIPES`'e satır + `AudioManager.EVENTS`'e yol +
bu dosyaya satır. `.import` dosyaları `compress/mode=0` (PCM) ile takip ediliyor.
Ölçüm: `godot --headless --audio-driver Dummy --path . --script res://tools/audio_probe.gd`.
