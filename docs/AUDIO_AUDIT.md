# AUDIO_AUDIT.md — Ses + titreşim envanteri ve mimarisi (M8.5-15)

> Bu dosya **ses sisteminin gerçek durumunu** anlatır: hangi dosya nerede
> çalıyor, hangi kalitede, ne KEEP / ne REPLACE. Kilitli tasarım sayısı
> içermez (GAME_DESIGN §6 nitel kalır). Eksik final örneklerin şartnamesi:
> [`AUDIO_ASSET_REQUIREMENTS.md`](AUDIO_ASSET_REQUIREMENTS.md).

## 0. Dürüst özet

- **Sistem production-ready:** merkezi olay tablosu, öncelikli kanal
  yönetimi, soğuma/tavan, yerel RNG, HardLimiter, Ayarlar'da gerçek SFX +
  Titreşim anahtarları, Android için yerleşik `Input.vibrate_handheld`
  tabanı, otomatik test (47 kontrol) ve QA sahnesi.
- **Sesler production-ready DEĞİL.** Repoda 7 Kenney CC0 placeholder vardı,
  başka kaynak yoktu (`_audio_source/` bu makinede yok, gitignore'lu).
  Bu turda 22 kısa ses `tools/make_sfx.gd` ile **sentezlendi** (saf sinüs /
  süzülmüş gürültü, kırpmasız, ≤ −3 dBFS). Bunlar sessizlikten ve "her
  şeye aynı thud"tan iyidir; **kulakla doğrulanmadılar** (üretim ortamında
  ses çıkışı yok) ve **final olarak sunulmuyorlar**. Sınıflandırma aşağıda.
- **Android titreşimi fiziksel olarak DOĞRULANMADI** (cihaz bağlı değil).
  Editor'de "desteklenmiyor → sessizce false" yolu doğrulandı. Gerçek cihaz
  QA'sı M9.

## 1. Bu turdan önceki envanter (M6 placeholder'ları)

Ölçümler `tools/audio_probe.gd` (AudioEffectCapture, Dummy sürücü):

| eski dosya | kaynak (Kenney CC0) | nerede çalıyordu | süre | tepe | RMS | kırpma | karar |
|---|---|---|---|---|---|---|---|
| `sfx_merge_pop.ogg` | Impact Sounds `impactSoft_medium_000` | merge (tier pitch), bomba (0.75), büyütücü, temizleyici (1.15) | 0.19 s | −1.0 dB | −16.3 | 0 | **KEEP → `kenney_impact_soft_01.ogg`**, rolü değişti: iniş + merge'in pes gövde katmanı. Merge imza sesi olarak yumuşak bir thud'dı, "candy pop" değil. |
| `sfx_danger.ogg` | Digital Audio `lowDown` | tehlike tik'i (0.5 s'de bir!), sarsıntı (0.8), taşma (0.7) | 0.84 s | −0.6 dB | −10.4 | 0 | **REMOVE.** Retro-dijital inen ton, tepe sıfıra yakın, 0.84 s; yarım saniyede bir tekrar edince siren etkisi. Yerine yumuşak iki notalı `sfx_danger_soft_01` (interim). |
| `sfx_combo.ogg` | Digital Audio `pepSound1` | combo (pitch ×1.06/adım) | 0.56 s | −1.0 dB | −13.1 | 0 | **REMOVE.** Arcade "pep" karakteri candy tona aykırı, yüksek. Yerine parıltı arpeji (interim). |
| `sfx_star_pat.ogg` | Interface Sounds `pluck_001` | yıldız reveal, equip, kilitli kart, anahtar | 0.19 s | **+0.4 dB** | −23.1 | **1** | **KEEP (MODIFY: kazanç)** → `kenney_pluck_01.ogg`. Tek örnek kırpıyor; tabloda −8…−14 dB ile çalınıyor + bus limiter. Roller: yıldız reveal, anahtar açma, kart seçme, güç silahlanma. |
| `sfx_chest_open.ogg` | Interface Sounds `open_001` | sandık açılışı, satın alma, refill | 0.19 s | −1.5 dB | −16.0 | 0 | **KEEP** → `kenney_open_01.ogg`, YALNIZCA sandık "açılış" aşaması. Satın alma/refill artık ayrı ödül cue'su. |
| `sfx_level_win.ogg` | Music Jingles `jingles_PIZZI07` | round kazanma, devam (1.15) | 1.39 s | −5.7 dB | −17.5 | 0 | **KEEP** → `kenney_jingle_win_01.ogg`, yalnız round kazanma. Uzunluk "kısa sting" sınırında; kulakla stil onayı owner'da. |
| `sfx_level_lose.ogg` | Music Jingles `jingles_PIZZI16` | round kaybetme | 0.46 s | −5.4 dB | −17.3 | 0 | **KEEP** → `kenney_jingle_lose_01.ogg`, yalnız kesin kayıp. Taşma anı ayrı (`fail`). |

Eski mimarinin sorunları: 8 kanal round-robin (ödül sesi bir sonraki
inişle kesilebiliyordu), olay başına soğuma/tavan yok (yığın inişi = 10
çarpma sesi), bırakma / iniş / UI / güç aktivasyonu için hiç ses yok, aynı
`chest_open` üç farklı anlamda, `danger` üç farklı anlamda.

## 2. Mimari

- **`AudioManager` (autoload, `scripts/autoload/audio_manager.gd`)** — tek
  çalma noktası. `EVENTS` tablosu: olay → varyant havuzu, gain_db, pitch,
  jitter, cooldown_ms, max_voices, steal_self, priority, layers, fallback.
  Yardımcılar: `play(id, pitch_mul, gain_offset_db)`, `play_drop()`,
  `play_landing(tier, speed)`, `play_merge(tier)`, `play_combo(n)`,
  `play_reward(rarity)`, `set_sfx_enabled()`.
- **Bus:** Master → **SFX** (AudioEffectHardLimiter, tavan −0.5 dB, release
  60 ms) → çağrı noktaları değişmeden mute; Music bus boş (v1 non-goal,
  sahte müzik anahtarı YOK). `default_bus_layout.tres`.
- **Kanal yönetimi:** 12 `AudioStreamPlayer` (mobil için ılımlı). Boş kanal
  yoksa: LOW < NORMAL < HIGH < CRITICAL. Eşit öncelikte yalnız NORMAL ve
  altı kesilebilir; HIGH'ı yalnız CRITICAL keser; **CRITICAL asla kesilmez**
  (Tier 8 kutlaması, Legendary, round_win, revive, Epic ödül).
- **Spam koruması (olay başına):** `cooldown_ms` (aynı olayın iki çalışı
  arası) + `max_voices` (eşzamanlı tavan) + `steal_self` (tavana gelince en
  eskisini kes / yenisini at). Örnek: iniş = 55 ms + 2 kanal + at → 10
  parça aynı karede inince 2 ses; merge = 30 ms + 4 kanal + kes; temizleyici
  pufu = 45 ms + 3 kanal; UI tık = 40 ms + 1 kanal.
- **Yerel RNG:** `_rng` sabit tohumlu (`AUDIO_RNG_SEED`); varyant seçimi ve
  pitch/gain jitter buradan. Global `randf/randi` KULLANILMIYOR — test
  `seed()` sonrası `randi()` dizisinin değişmediğini doğruluyor.
- **Eksik dosya:** olay `fallback`'e düşer, o da yoksa sessiz + `play()`
  false; açılışta TEK `push_warning` ile liste. Çökme yok.
- **Haptics (`scripts/haptics.gd`, `class_name Haptics`, statik, autoload
  değil):** LIGHT 18 ms / MEDIUM 32 ms / STRONG 55 ms (+amplitude
  0.35/0.65/1.0 destekleyen Android'de), SPECIAL = 35 ms + 60 ms boşluk +
  60 ms. `MIN_GAP_MS` 70: pencere içinde yalnız daha güçlü darbe geçer.
  Editor/masaüstünde `is_supported()` false → platform çağrısı yok.
  Ayar: `SaveManager.haptics_enabled` (varsayılan true), Ayarlar → Titreşim.

## 3. Olay → ses eşlemesi (final tablo `AudioManager.EVENTS`)

| olay | çağrı noktası | dosya(lar) | gain | pitch | soğuma / tavan | öncelik | titreşim |
|---|---|---|---|---|---|---|---|
| `ui_tap` | `UiMotion.attach_press/attach_tap` (bütün butonlar, `button_down`) | `ui/sfx_ui_tap_01.wav` | −13 | 1.0 | 40 ms / 1 kes | LOW | yok |
| `ui_tab` | `TabBar.set_active` (değişince) | `ui/sfx_ui_tab_01.wav` | −15 | 1.0 | 60 / 1 kes | LOW | yok |
| `ui_modal_open` | ayarlar, mağaza onayı, refill penceresi | `ui/sfx_ui_modal_open_01.wav` | −10 | 1.0 | 80 / 1 kes | NORMAL | yok |
| `ui_modal_close` | aynı pencerelerin kapanışı, günlük ödül kapat | `ui/sfx_ui_modal_close_01.wav` | −12 | 1.0 | 80 / 1 kes | LOW | yok |
| `ui_toggle_on` | Ayarlar → Ses Efektleri açılınca | `ui/kenney_pluck_01.ogg` | −12 | 1.2 | 80 / 1 | LOW | Titreşim anahtarı açılınca MEDIUM |
| `ui_select` | koleksiyonda kilitli kart odaklama | `ui/kenney_pluck_01.ogg` | −14 | 0.85 | 60 / 1 kes | LOW | yok |
| `ui_purchase` | mağaza satın alma, Hamurla/ödüllü refill | `rewards/sfx_reward_chime_01.wav` | −5 | 1.0 | 120 / 1 | HIGH | MEDIUM |
| `ui_invalid` | Hamur yetmedi (mağaza yarış durumu, refill) | `ui/sfx_ui_invalid_01.wav` | −9 | 1.0 | 150 / 1 | NORMAL | yok |
| `ui_equip` | skin takıldı (`skin_equipped`) | `rewards/sfx_sparkle_up_01.wav` | −7 | 1.1 | 120 / 1 | NORMAL | LIGHT |
| `drop` | `GameBoard._drop` | `gameplay/sfx_drop_01..03.wav` | −14 (±0) | jitter ±3 % | 60 / 2 at | LOW | yok |
| `land` | `Dumpling.impact_landed` (≥ 420 px/s) | `gameplay/kenney_impact_soft_01.ogg` | −9 −8…0 (hıza göre) ±1 | tier 1 → 8: 1.25 → 0.78, ±4 % | 55 / 2 at | LOW | yok |
| `merge` | `_resolve_merge` (her merge) | `gameplay/sfx_merge_pop_01..03.wav` | −1 ±0 | `TierConfig.merge_pitch` ±2 % | 30 / 4 kes | NORMAL | tier < 6 LIGHT |
| `merge_body` | `play_merge` katmanı | `gameplay/kenney_impact_soft_01.ogg` | tier 1 → 8: −14 → −4 | 1.15 → 0.7 | 30 / 3 kes | NORMAL | — |
| `merge_high` | `play_merge`, tier 6–7 | `rewards/sfx_sparkle_up_01.wav` | −8 | 0.9 / 0.95 | 120 / 2 | HIGH | MEDIUM |
| `tier_max` | `play_merge`, tier 8 (büyütücüyle de) | `rewards/sfx_sparkle_big_01.wav` | −2 | 1.0 | 300 / 1 | **CRITICAL** | **SPECIAL** |
| `annihilation` | sonsuz mod 8+8 | `sfx_merge_pop_01` + `tier_max` katmanı | −1 | 0.7 | 100 / 1 | HIGH | STRONG |
| `combo` | `_register_combo` (≥ x2) | `rewards/sfx_sparkle_up_01.wav` | −9 | 1 + 0.04·min(n,8) | 90 / 2 kes | NORMAL | yok (merge taşıyor) |
| `danger` | taşma bandında 0.5 s'de bir | `gameplay/sfx_danger_soft_01.wav` | −10 | 1.0 | 400 / 1 | NORMAL | yok |
| `fail` | taşma → devam teklifi | `gameplay/sfx_fail_soft_01.wav` | −6 | 1.0 | 500 / 1 | HIGH | MEDIUM (tek) |
| `round_lose` | `_finish(false)` | `gameplay/kenney_jingle_lose_01.ogg` | −6 | 1.0 | 500 / 1 | HIGH | yok |
| `round_win` | `_finish(true)` | `rewards/kenney_jingle_win_01.ogg` | −4 | 1.0 | 500 / 1 | CRITICAL | yok (hedef kutlaması görsel) |
| `revive` | `grant_revive` | `gameplay/sfx_revive_01.wav` | −5 | 1.0 | 500 / 1 | CRITICAL | MEDIUM |
| `power_arm` | hedefleme moduna girince | `ui/kenney_pluck_01.ogg` | −12 | 1.05 | 80 / 1 kes | LOW | yok |
| `bomb_whoosh` | mermi fırlarken | `powers/sfx_whoosh_01.wav` | −10 | 1.0 | 100 / 1 | NORMAL | yok |
| `bomb_impact` | `_detonate_bomb` | `powers/sfx_bomb_impact_01.wav` + `merge_body` | −2 ±3 % | 1.0 | 100 / 1 | HIGH | STRONG |
| `upgrade` | `_run_upgrade` (+ `play_merge(new_tier)`) | `powers/sfx_upgrade_01.wav` | −4 | 1.0 | 150 / 1 | HIGH | MEDIUM |
| `shake` | `_use_shake` | `powers/sfx_shake_01.wav` | −7 | 1.0 | 200 / 1 | NORMAL | MEDIUM (tek darbe) |
| `clear_puff` | `_pop_and_free` (parça başına, kademeli) | `powers/sfx_puff_01.wav` | −9 ±1.5 | 1 + 0.04·tier ±8 % | 45 / 3 at | LOW | LIGHT (aktivasyonda bir kez) |
| `star_reveal` | round sonu yıldızlar | `ui/kenney_pluck_01.ogg` | −8 | 1 + 0.12·i | 100 / 2 | NORMAL | yok |
| `chest_open` | sandık kartı belirince (beklenti) | `rewards/kenney_open_01.ogg` | −6 | 0.9 | 150 / 1 | NORMAL | — |
| `reward_common` | reveal, Common / teselli | `gameplay/sfx_merge_pop_02.wav` | −6 | 1.1 | 150 / 1 | HIGH | Hamur LIGHT, skin MEDIUM |
| `reward_rare` | reveal, Rare | `rewards/sfx_sparkle_up_01.wav` | −5 | 1.0 | 150 / 1 | HIGH | aynı |
| `reward_epic` | reveal, Epic | `sfx_sparkle_up_01` + `ui_purchase` katmanı | −3 | 1.12 | 150 / 1 | CRITICAL | MEDIUM |
| `reward_legendary` | reveal, Legendary | `rewards/sfx_sparkle_big_01.wav` | −1 | 1.0 | 300 / 1 | CRITICAL | **SPECIAL** |
| `daily_reward` | günlük ödül penceresi | `rewards/sfx_reward_chime_01.wav` | −5 | 0.95 | 300 / 1 | HIGH | yok |
| `level_unlock` | harita düğüm açılış pop'u | `rewards/sfx_sparkle_up_01.wav` | −6 | 1.05 | 300 / 1 | HIGH | yok |

Mix hiyerarşisi: merge / büyük ödül / güç vuruşu / tier 8 en önde (−1…−2),
iniş / satın alma / sandık / unlock ortada (−4…−9), bırakma / UI / sekme
sessiz (−12…−15). Tehlike −10 (okunur ama baskın değil). Her dosyanın ham
tepesi ≤ −3 dBFS (Kenney istisnaları tabloda), üstüne SFX bus limiter.

**Bilinçli olarak ses YOK:** skor "+N" pop'u (merge zaten çalıyor, her
sayı animasyonuna ses gürültü olurdu), hedef kutlaması (round_win onu
kapsıyor), devam teklifi penceresi (taşma tonu sunum sesi), tutorial.

## 4. Titreşim politikası (özet)

| olay | seviye |
|---|---|
| buton / sekme / bırakma / iniş / combo sayısı / tehlike tik'i | YOK |
| normal merge (tier < 6) | LIGHT |
| yüksek tier merge (6–7), büyütücü, sarsıntı (tek), satın alma, refill, devam, taşma (tek), Epic ödül, yeni skin | MEDIUM |
| bomba vuruşu, sonsuz yok oluşu | STRONG |
| Tier 7 → 8, Legendary ödül | SPECIAL (iki darbe) |
| temizleyici | LIGHT bir kez (parça başına değil) |
| skin tak, Hamur ödülü | LIGHT |
| Titreşim anahtarı açılınca | MEDIUM (onay) |

Zincir merge'de 70 ms penceresi hafif darbeleri yutar; Tier 8 STRONG
pencereyi deler. Uzun titreşim yok (en uzunu 60 ms).

## 5. Asset sınıflandırması (KEEP / MODIFY / REPLACE)

| dosya | kaynak | sınıf | not |
|---|---|---|---|
| `gameplay/kenney_impact_soft_01.ogg` | Kenney CC0 | **KEEP** (iniş, gövde katmanı) | kulakla stil onayı owner'da |
| `ui/kenney_pluck_01.ogg` | Kenney CC0 | **MODIFY** (kazanç −8…−14 dB) | +0.4 dBFS tepe, bir örnek kırpıyor; limiter'la güvenli |
| `rewards/kenney_open_01.ogg` | Kenney CC0 | **KEEP** (sandık açılış aşaması) | |
| `rewards/kenney_jingle_win_01.ogg` | Kenney CC0 | **KEEP / owner onayı** | pizzicato jingle 1.4 s |
| `gameplay/kenney_jingle_lose_01.ogg` | Kenney CC0 | **KEEP / owner onayı** | 0.46 s inen pizzicato |
| `sfx_danger.ogg`, `sfx_combo.ogg` | Kenney CC0 | **REMOVED** | Digital Audio paketi, candy tona aykırı; Kenney'den yeniden indirilebilir |
| `sfx_*.wav` (22 dosya) | `tools/make_sfx.gd` sentez (bu repo, CC0 sayılabilir — kendi üretimimiz) | **INTERIM → REPLACE** | kulakla doğrulanmadı; şartname `AUDIO_ASSET_REQUIREMENTS.md`; aynı adla üzerine yazılınca kod değişmez |

Sentez dosyalarının ölçümleri (probe): süre 0.05–1.1 s, tepe −3…−9 dBFS,
kırpma 0, baş fade 2 ms, kuyruk ≤ 120 ms sessizlik.

## 6. Doğrulanan / doğrulanmayan

**Doğrulandı (otomatik, headless, Dummy sürücü):** `tools/audio_test.gd`
47/47 — yükleme, 31 beklenen olay + akış, bilinmeyen olay / silinen akış
çökmez, tablo tutarlılığı, global RNG izolasyonu, iniş spam (10 → ≤2),
soğuma, merge steal_self, CRITICAL korunması, SFX/haptics ayar kalıcılığı,
haptics kapalı → platform çağrısı yok, editor'de destek yok → güvenli,
spam penceresi, SPECIAL iki darbe, ≤ 60 ms, gameplay durumu değişmiyor.
Mevcut testler: ui_smoke 67/67, economy 100/100, refill 119/119, revive
103/103, skin 25/25, bot L3 2/2 kazandı. Pencereli (gerçek WASAPI sürücü):
`ui_shots` 13 çekim hatasız (Ayarlar'da Titreşim satırı görüldü).

**Doğrulanmadı:** hiçbir ses **kulakla** dinlenmedi (ortamda çıkış yok);
kırpma/stil/hoşluk yalnızca sayısal. Android titreşimi cihazda
hissedilmedi. Owner'ın yapması gereken: `tools/audio_qa.tscn` ile her
düğmeye basıp dinlemek; itiraz edilen her dosyayı şartnameye göre
değiştirmek. Android: VIBRATE izni export preset'inde açık olmalı (M9).
