# AUDIO_SYSTEM.md — production SFX system (M8.8-02, canonical)

**Status: this file describes the ACTUAL implemented runtime** on branch
`task/032-production-audio-integration` (M8.8-02). It supersedes the interim
description in `docs/AUDIO_AUDIT.md` (M8.5-15) and the candidate palette in
`build/qa_m8.8-01/`. If code and this document disagree, the code is wrong or this
document is stale — fix one of them, do not leave both.

Companion documents:
- `docs/audio/MERGE_SOUND_FAMILY.md` — the owner-approved merge family (T1–T8 recipe).
- `docs/audio/HAPTIC_MAPPING.md` — exact vibration mapping.
- `docs/audio/PRODUCTION_FILES.md` — generated manifest: every production file with source,
  licence, processing and measurements (`tools/audio_production_build.py`).
- `assets/audio/CREDITS.md` — provenance and licence summary per source.
- `docs/licenses/audio/` — the licence texts shipped with the source packs.

## 1. Owner decisions this build implements (locked, M8.8-02 brief)

| category | owner decision | implemented as |
|---|---|---|
| Merge family | **A — premium** (soft pop/body → glass/chime escalation → T8 bell bloom + music-box note + twinkle tail; T8 wider/longer, not louder) | `merge` + tier-banded body pools + `merge_sparkle` (T3+) + `merge_chime` (T5+) + `tier_max` bloom/box/tail |
| Büyütücü | **C — minimal relaxed** (tap immediately audible, 150 ms anticipation unchanged, restrained transform, then merge family) | `upgrade` at the tap, `upgrade_transform` + `play_merge(new_tier)` at the transform |
| Drop | **C** | `land` (+ the quiet `drop` release tick from the same file) |
| Bomba | **A** — launch/whoosh + impact + soft poof, cute and compact | `bomb_whoosh` → `bomb_impact` + `bomb_poof` (+15 ms) |
| Temizleyici | **B** — pop character primary, subtle sweep underneath | `clear_puff` (3 sliced pops, existing stagger) + `clear_sweep` once at activation |
| Win / Fail | **B / B** | `round_win` (steel jingle), `round_lose` + `fail` (pizzicato) |
| Chest open | **A** (owner listening decision over the audit's concern) | `chest_open` (latch, −6 dB) |
| Dough reward | approved candidate | `reward_common`, `daily_reward` |
| Legendary | previous candidate **rejected** → composition from approved layers | `reward_legendary` = bloom + box + box↑ + tail |
| UI | TAP / CONFIRM / BACK / ERROR approved, one family | all UI events map onto these four Kenney Interface files |
| Sarsıntı | all candidates rejected → Claude's pick from the pool | `shake` = `Accept Boing Crunch` warble (Sonniss CSD) |
| Danger | all candidates rejected → Claude's pick from the pool | `danger` = Kenney `impactWood_light_001/003` soft tok |
| Haptics | T1–T3 none · T4–T5 LIGHT · T6–T7 MEDIUM · T8 SPECIAL; powers unchanged | `Haptics.merge_tier()`; see HAPTIC_MAPPING.md |
| No extra polish | no container sway, no new VFX, no gameplay change | nothing outside `AudioManager`, `Haptics` and three audio call lines in `game_board.gd` changed |

## 2. Architecture (`scripts/autoload/audio_manager.gd`)

- **Single play point.** Call sites use event ids (`AudioManager.play(&"bomb_impact")`,
  `play_merge(tier)`, `play_landing(tier, speed)`, `play_drop()`, `play_combo(n)`,
  `play_reward(rarity)`); file paths live only in `EVENTS`.
- **Buses:** Master → **SFX** (AudioEffectHardLimiter, ceiling −0.5 dB) → all voices;
  Music bus exists but is empty (v1 non-goal). Settings → "Ses Efektleri" mutes the SFX
  bus (`set_sfx_enabled`); play() keeps running muted, nothing else changes.
- **Voices:** 12 `AudioStreamPlayer`s. When none is free, priority decides:
  LOW < NORMAL < HIGH < CRITICAL; equal priority steals only NORMAL and below; HIGH is
  stolen only by CRITICAL; **CRITICAL is never stolen** (T8 layers, Legendary, win,
  revive, Epic).
- **Per-event spam control:** `cooldown_ms` (minimum gap between two plays of the same
  event), `max_voices` (concurrent cap), `steal_self` (at the cap: cut the oldest, or
  drop the new one). Ten landings in one frame = two sounds.
- **Layers and delays (new in M8.8-02):** `layers` lists extra events played with the
  primary (same pitch multiplier, no gain offset); every event may carry `delay_ms`,
  measured from the **call moment** (not from the parent layer). Delays use a
  `SceneTreeTimer` per scheduled layer — **no `_process` loop**. `stop_all()` bumps a
  generation counter so pending timers fire as no-ops; `pending_delayed()` exposes the
  count for tests. Layer trees are expanded recursively (`MAX_LAYER_DEPTH` 3, cycle-safe).
  A delayed layer still obeys its own cooldown / voice cap / priority when it fires.
  The three T8 layers allow 2 voices (M8.8-02.1): a second T8 stack 0.3–1.1 s after the
  first (chain, Büyütücü, endless annihilation) keeps its bloom/box/tail; the 300 ms cooldown
  still blocks same-frame doubles.
- **Local RNG:** variant choice and pitch/gain jitter come from a seeded
  `RandomNumberGenerator` (`AUDIO_RNG_SEED`), including inside delayed callbacks; the
  global `randf/randi` sequence is never touched (drop-bag determinism).
- **Missing files:** an event whose files are missing resolves to its `fallback` event's
  pool (chained: `merge_body_large` → `merge_body_full` → `merge_body_light`); without
  a fallback it is silent and `play()` returns false. One `push_warning` at start-up
  lists the missing ids. Nothing crashes.

## 3. Production event map (dumped from `AudioManager.EVENTS`)

Gains are `volume_db` on the voice before the bus limiter; the per-tier merge overrides
are in `MERGE_RECIPE` (see MERGE_SOUND_FAMILY.md). `delay ms` is the offset from the call.

| event | streams | gain dB | pitch | jitter (pitch / gain dB) | delay ms | cooldown ms | max voices | steal self | priority | layers | fallback |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `ui_tap` | `ui/sfx_ui_tap_01.wav` | -11 | 1.00 | 0.00 / 0.0 | 0 | 40 | 1 | yes | LOW | — | — |
| `ui_tab` | `ui/sfx_ui_tap_01.wav` | -13 | 1.15 | 0.00 / 0.0 | 0 | 60 | 1 | yes | LOW | — | — |
| `ui_modal_open` | `ui/sfx_ui_confirm_01.wav` | -12 | 0.95 | 0.00 / 0.0 | 0 | 80 | 1 | yes | NORMAL | — | — |
| `ui_modal_close` | `ui/sfx_ui_back_01.wav` | -11 | 1.00 | 0.00 / 0.0 | 0 | 80 | 1 | yes | LOW | — | — |
| `ui_toggle_on` | `ui/sfx_ui_confirm_01.wav` | -12 | 1.20 | 0.00 / 0.0 | 0 | 80 | 1 | no | LOW | — | — |
| `ui_select` | `ui/sfx_ui_tap_01.wav` | -13 | 0.90 | 0.00 / 0.0 | 0 | 60 | 1 | yes | LOW | — | — |
| `ui_purchase` | `ui/sfx_ui_confirm_01.wav` | -5 | 1.00 | 0.00 / 0.0 | 0 | 120 | 1 | no | HIGH | — | — |
| `ui_invalid` | `ui/sfx_ui_error_01.wav` | -9 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | NORMAL | — | — |
| `ui_equip` | `ui/sfx_ui_confirm_01.wav` | -7 | 1.10 | 0.00 / 0.0 | 0 | 120 | 1 | no | NORMAL | — | — |
| `drop` | `gameplay/sfx_land_01.wav` | -18 | 1.35 | 0.03 / 0.0 | 0 | 60 | 2 | no | LOW | — | — |
| `land` | `gameplay/sfx_land_01.wav` | -9 | 1.00 | 0.04 / 1.0 | 0 | 55 | 2 | no | LOW | — | — |
| `merge` | `gameplay/sfx_merge_pop_01.wav`, `gameplay/sfx_merge_pop_02.wav` | -1 | 1.00 | 0.02 / 1.0 | 0 | 30 | 4 | yes | NORMAL | — | — |
| `merge_body_light` | `gameplay/sfx_merge_body_light_01.wav`, `gameplay/sfx_merge_body_light_02.wav` | -12 | 1.00 | 0.00 / 1.0 | 0 | 30 | 3 | yes | NORMAL | — | — |
| `merge_body_full` | `gameplay/sfx_merge_body_full_01.wav`, `gameplay/sfx_merge_body_full_02.wav` | -8 | 1.00 | 0.00 / 1.0 | 0 | 30 | 3 | yes | NORMAL | — | `merge_body_light` |
| `merge_body_large` | `gameplay/sfx_merge_body_large_01.wav` | -6 | 1.00 | 0.00 / 1.0 | 0 | 30 | 2 | yes | NORMAL | — | `merge_body_full` |
| `merge_sparkle` | `gameplay/sfx_merge_sparkle_01.wav`, `gameplay/sfx_merge_sparkle_02.wav`, `gameplay/sfx_merge_sparkle_03.wav` | -14 | 1.00 | 0.03 / 1.0 | 30 | 30 | 3 | yes | NORMAL | — | — |
| `merge_chime` | `gameplay/sfx_merge_chime_01.wav` | -11 | 1.00 | 0.00 / 0.5 | 45 | 60 | 2 | yes | NORMAL | — | — |
| `tier_max` | `rewards/sfx_tier8_bloom_01.wav` | -7 | 1.00 | 0.00 / 0.0 | 20 | 300 | 2 | no | CRITICAL | `tier_max_box`, `tier_max_tail` | — |
| `tier_max_box` | `rewards/sfx_tier8_box_01.wav` | -10 | 1.00 | 0.00 / 0.0 | 70 | 300 | 2 | no | CRITICAL | — | — |
| `tier_max_tail` | `rewards/sfx_tier8_tail_01.wav` | -14 | 1.00 | 0.00 / 0.0 | 120 | 300 | 2 | no | CRITICAL | — | — |
| `annihilation` | `gameplay/sfx_merge_body_large_01.wav` | -3 | 0.75 | 0.00 / 0.0 | 0 | 100 | 1 | no | HIGH | `tier_max` | — |
| `combo` | `gameplay/sfx_merge_sparkle_01.wav`, `gameplay/sfx_merge_sparkle_02.wav`, `gameplay/sfx_merge_sparkle_03.wav` | -11 | 1.00 | 0.00 / 0.0 | 0 | 90 | 2 | yes | NORMAL | — | — |
| `danger` | `gameplay/sfx_danger_01.wav`, `gameplay/sfx_danger_02.wav` | -10 | 1.00 | 0.02 / 0.0 | 0 | 400 | 1 | no | NORMAL | — | — |
| `fail` | `gameplay/sfx_round_lose_01.wav` | -7 | 0.94 | 0.00 / 0.0 | 0 | 500 | 1 | no | HIGH | — | — |
| `round_lose` | `gameplay/sfx_round_lose_01.wav` | -6 | 1.00 | 0.00 / 0.0 | 0 | 500 | 1 | no | HIGH | — | — |
| `round_win` | `rewards/sfx_round_win_01.wav` | -4 | 1.00 | 0.00 / 0.0 | 0 | 500 | 1 | no | CRITICAL | — | — |
| `revive` | `rewards/sfx_round_win_01.wav` | -6 | 0.90 | 0.00 / 0.0 | 0 | 500 | 1 | no | CRITICAL | — | — |
| `power_arm` | `ui/sfx_ui_confirm_01.wav` | -13 | 1.15 | 0.00 / 0.0 | 0 | 80 | 1 | yes | LOW | — | — |
| `bomb_whoosh` | `powers/sfx_bomb_launch_01.wav` | -10 | 1.00 | 0.00 / 0.0 | 0 | 100 | 1 | no | NORMAL | — | — |
| `bomb_impact` | `powers/sfx_bomb_impact_01.wav` | -2 | 1.00 | 0.03 / 0.0 | 0 | 100 | 1 | no | HIGH | `bomb_poof` | — |
| `bomb_poof` | `powers/sfx_bomb_poof_01.wav` | -10 | 1.00 | 0.00 / 0.0 | 15 | 100 | 1 | no | NORMAL | — | — |
| `upgrade` | `powers/sfx_upgrade_charge_01.wav` | -9 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | HIGH | — | — |
| `upgrade_transform` | `powers/sfx_upgrade_air_01.wav` | -14 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | NORMAL | — | — |
| `shake` | `powers/sfx_shake_01.wav` | -5 | 1.00 | 0.00 / 0.0 | 0 | 200 | 1 | no | NORMAL | — | — |
| `clear_sweep` | `powers/sfx_clear_sweep_01.wav` | -14 | 1.00 | 0.00 / 0.0 | 0 | 200 | 1 | no | NORMAL | — | — |
| `clear_puff` | `powers/sfx_clear_pop_01.wav`, `powers/sfx_clear_pop_02.wav`, `powers/sfx_clear_pop_03.wav` | -7 | 1.00 | 0.08 / 1.5 | 0 | 40 | 3 | no | LOW | — | — |
| `star_reveal` | `gameplay/sfx_merge_sparkle_01.wav` | -8 | 1.00 | 0.00 / 0.0 | 0 | 100 | 2 | no | NORMAL | — | — |
| `chest_open` | `rewards/sfx_chest_open_01.wav` | -6 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | NORMAL | — | — |
| `reward_common` | `rewards/sfx_reward_dough_01.wav` | -6 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | HIGH | — | — |
| `reward_rare` | `rewards/sfx_tier8_tail_01.wav` | -6 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | HIGH | — | — |
| `reward_epic` | `rewards/sfx_tier8_box_01.wav` | -6 | 1.00 | 0.00 / 0.0 | 0 | 150 | 1 | no | CRITICAL | `reward_epic_tail` | — |
| `reward_epic_tail` | `rewards/sfx_tier8_tail_01.wav` | -7 | 1.00 | 0.00 / 0.0 | 60 | 150 | 1 | no | CRITICAL | — | — |
| `reward_legendary` | `rewards/sfx_tier8_bloom_01.wav` | -4 | 1.00 | 0.00 / 0.0 | 0 | 300 | 1 | no | CRITICAL | `reward_legendary_box`, `reward_legendary_box_up`, `reward_legendary_tail` | — |
| `reward_legendary_box` | `rewards/sfx_tier8_box_01.wav` | -7 | 1.00 | 0.00 / 0.0 | 60 | 300 | 1 | no | CRITICAL | — | — |
| `reward_legendary_box_up` | `rewards/sfx_tier8_box_01.wav` | -8 | 1.34 | 0.00 / 0.0 | 220 | 300 | 1 | no | CRITICAL | — | — |
| `reward_legendary_tail` | `rewards/sfx_tier8_tail_01.wav` | -9 | 1.00 | 0.00 / 0.0 | 120 | 300 | 1 | no | CRITICAL | — | — |
| `daily_reward` | `rewards/sfx_reward_dough_01.wav` | -5 | 0.95 | 0.00 / 0.0 | 0 | 300 | 1 | no | HIGH | — | — |
| `level_unlock` | `rewards/sfx_tier8_tail_01.wav` | -7 | 1.05 | 0.00 / 0.0 | 0 | 300 | 1 | no | HIGH | — | — |

Mix hierarchy: merge POP / power hits / T8 bloom in front (−1…−7), landing / purchase /
chest / rewards in the middle (−5…−9), danger −10, release tick and UI quiet (−11…−18).
The UI family is always quieter than merges and powers (asserted by `tools/audio_test`).

## 4. Roles, sources and licences per event

| event(s) | role in the game | production file(s) | source | licence |
|---|---|---|---|---|
| `merge` | merge POP core, pitch `TierConfig.merge_pitch` 0.85→1.48× (GAME_DESIGN §6) | `gameplay/sfx_merge_pop_01/02.wav` | Sonniss · Cinematic Sound Design "Cartoon & Animation Vol 2" — `Cartoon Bubbles Short.wav` (the two bubbles of one file) | Sonniss GDC 2026 royalty-free |
| `merge_body_light` | merge body T1–T3 | `gameplay/sfx_merge_body_light_01/02.wav` | Kenney Impact `impactGeneric_light_002/004` | CC0 |
| `merge_body_full` | merge body T4–T6 | `gameplay/sfx_merge_body_full_01/02.wav` | Kenney Impact `impactPlate_light_003`, `impactPlate_medium_001` | CC0 |
| `merge_body_large` | merge body T7–T8, `annihilation` body | `gameplay/sfx_merge_body_large_01.wav` | Kenney Impact `impactPunch_medium_001` | CC0 |
| `merge_sparkle`, `combo`, `star_reveal` | tiny glass sparkle T3+, combo sweetener (+4 %/step), result stars | `gameplay/sfx_merge_sparkle_01/02/03.wav` | Kenney Impact `impactGlass_light_002/000/004` | CC0 |
| `merge_chime` | soft bell T5–T7 (+45 ms) | `gameplay/sfx_merge_chime_01.wav` | Kenney Impact `impactBell_heavy_002` | CC0 |
| `tier_max`, `reward_legendary` | T8 warm bloom (+20 ms), Legendary bloom | `rewards/sfx_tier8_bloom_01.wav` | Kenney Impact `impactBell_heavy_000` | CC0 |
| `tier_max_box`, `reward_epic`, `reward_legendary_box(_up)` | music-box note (+70 ms at T8) | `rewards/sfx_tier8_box_01.wav` | Sonniss · Sonic Bat "Music Boxes" — `SBmb_Music Box A 013.wav` (first note) | Sonniss GDC 2026 royalty-free |
| `tier_max_tail`, `reward_rare`, `reward_epic_tail`, `reward_legendary_tail`, `level_unlock` | short twinkle tail (+120 ms at T8), reward/unlock sparkle | `rewards/sfx_tier8_tail_01.wav` | Sonniss · Cinematic Sound Design "User Interface" — `Button Arp Twinkle.wav` (0.6 s) | Sonniss GDC 2026 royalty-free |
| `land`, `drop` | landing (pitch by tier 1.25→0.78, gain by speed), release tick (1.35×, −18 dB) | `gameplay/sfx_land_01.wav` | Kenney Impact `impactGeneric_light_001` (DROP C) | CC0 |
| `danger` | overflow-band tick every 0.5 s | `gameplay/sfx_danger_01/02.wav` | Kenney Impact `impactWood_light_001/003` | CC0 |
| `round_lose`, `fail` | round lost; overflow moment (0.94×) | `gameplay/sfx_round_lose_01.wav` | Kenney Music Jingles `jingles_PIZZI00` (FAIL B) | CC0 |
| `round_win`, `revive` | round won; revive granted (0.9×, −6 dB) | `rewards/sfx_round_win_01.wav` | Kenney Music Jingles `jingles_STEEL09` (WIN B) | CC0 |
| `bomb_whoosh` | Bomba launch (falling tone) | `powers/sfx_bomb_launch_01.wav` | Kenney Interface `minimize_006` | CC0 |
| `bomb_impact` | Bomba hit (STRONG haptic) | `powers/sfx_bomb_impact_01.wav` | Kenney Impact `impactPunch_medium_000` | CC0 |
| `bomb_poof` | soft poof +15 ms | `powers/sfx_bomb_poof_01.wav` | Kenney Impact `footstep_snow_000` | CC0 |
| `upgrade` | Büyütücü tap (rising tone) | `powers/sfx_upgrade_charge_01.wav` | Kenney Interface `maximize_006` | CC0 |
| `upgrade_transform` | Büyütücü transform (airy sweep, under the merge family) | `powers/sfx_upgrade_air_01.wav` | Sonniss · Cinematic Sound Design "Ultra Transitions & Impacts" — `Woosh Sweep Slide Infographics Basic.wav` | Sonniss GDC 2026 royalty-free |
| `shake` | Sarsıntı (jelly warble) | `powers/sfx_shake_01.wav` | Sonniss · Cinematic Sound Design "UI Interaction Elements" — `Accept Boing Crunch.wav` (0.015–0.470 s) | Sonniss GDC 2026 royalty-free |
| `clear_sweep` | Temizleyici activation sweep (under) | `powers/sfx_clear_sweep_01.wav` | Sonniss · Cinematic Sound Design "Cartoon & Animation Vol 2" — `Cartoon Pull Swoosh Readout.wav` (0.06–0.42 s) | Sonniss GDC 2026 royalty-free |
| `clear_puff` | Temizleyici per-piece pop (3 variants, existing 45 ms stagger) | `powers/sfx_clear_pop_01/02/03.wav` | Sonniss · Cinematic Sound Design "Cartoon Impacts" — `Cartoon Pops Random Sequence Reverb.wav` (three dry pops sliced) | Sonniss GDC 2026 royalty-free |
| `chest_open` | chest card appears | `rewards/sfx_chest_open_01.wav` | Sonniss · Epic Stock Media "HD Lock And Mechanism" — `MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav` | Sonniss GDC 2026 royalty-free |
| `reward_common`, `daily_reward` | Hamur / Common reveal; daily reward (0.95×) | `rewards/sfx_reward_dough_01.wav` | Sonniss · Cinematic Sound Design "UI Interaction Elements" — `Ting Coins.wav` (0–0.7 s) | Sonniss GDC 2026 royalty-free |
| `ui_tap`, `ui_tab`, `ui_select` | every button (`UiMotion`), orphan tab, card focus | `ui/sfx_ui_tap_01.wav` | Kenney Interface `select_002` (TAP) | CC0 |
| `ui_purchase`, `ui_toggle_on`, `ui_equip`, `ui_modal_open`, `power_arm` | confirm family at different gain/pitch | `ui/sfx_ui_confirm_01.wav` | Kenney Interface `confirmation_001` (CONFIRM) | CC0 |
| `ui_modal_close` | window close / back | `ui/sfx_ui_back_01.wav` | Kenney Interface `back_002` (BACK) | CC0 |
| `ui_invalid` | insufficient Hamur, locked node | `ui/sfx_ui_error_01.wav` | Kenney Interface `error_008` (ERROR) | CC0 |
| `annihilation` | endless 8+8 | `merge_body_large` file at 0.75× + the `tier_max` tree | as above | as above |

Exact processing per file (trim, HP/LP, fades, measured peak/RMS/length, phone-band
share): `docs/audio/PRODUCTION_FILES.md`.

## 5. Who fires what (call sites)

| call site | events | haptic |
|---|---|---|
| `UiMotion.attach_press/attach_tap` (`button_down`) | `ui_tap` | — |
| Settings / pause / daily / chest info / refill / shop confirm | `ui_modal_open`, `ui_modal_close` | — |
| Settings SFX toggle on | `ui_toggle_on` | Vibration toggle on → MEDIUM |
| Shop purchase, Hamur/rewarded refill | `ui_purchase` | MEDIUM |
| Insufficient Hamur (shop, refill, locked map node) | `ui_invalid` | shop: LIGHT |
| Skin equipped | `ui_equip` | LIGHT |
| Collection locked-card focus | `ui_select` | — |
| `GameBoard._drop` | `drop` | — |
| `GameBoard._on_impact_landed` (≥ 420 px/s) | `land` | — |
| `GameBoard._resolve_merge` | `play_merge(new_tier)` (+ `combo` from x2) | `Haptics.merge_tier(new_tier)` **(new mapping)** |
| `GameBoard._resolve_annihilation` | `annihilation` | STRONG |
| `GameBoard._on_power_armed_changed` | `power_arm` | — |
| `GameBoard._run_bomb` → `_detonate_bomb` | `bomb_whoosh` → `bomb_impact` (+`bomb_poof`) | STRONG at impact only |
| `GameBoard._run_upgrade` (tap) → `_finish_upgrade` (+150 ms) | `upgrade` → `upgrade_transform` **(new line)** + `play_merge(new_tier)` | MEDIUM; SPECIAL when the result is T8 |
| `GameBoard._use_shake` | `shake` | MEDIUM once |
| `GameBoard._use_clear_small` → `_pop_and_free` | `clear_sweep` **(new line)** → `clear_puff` per piece | LIGHT once at activation, never per piece |
| overflow band (every 0.5 s) | `danger` | — |
| overflow → revive offer | `fail` | MEDIUM |
| `grant_revive` | `revive` | MEDIUM |
| `_finish(won)` | `round_win` / `round_lose` | — |
| Round result stars (0.2 s stagger) | `star_reveal` (+12 %/star) | — |
| Reward card appears / opens | `chest_open` → `play_reward(rarity)` | Legendary SPECIAL, Epic MEDIUM, skin MEDIUM, Hamur LIGHT |
| Daily popup claim | `daily_reward` | — |
| Map node unlock pop | `level_unlock` | — |

## 6. Verification

- `tools/audio_test.tscn` — 117 checks (loading, file hygiene/format, fallback chain,
  RNG isolation, merge recipe per tier, delayed layers + cleanup, cooldown/voices,
  priority matrix, settings, haptic dictionary + merge mapping, call-site source scan,
  gameplay state untouched). Run: `godot --headless --audio-driver Dummy --path .
  res://tools/audio_test.tscn`.
- `tools/audio_event_render.tscn` — renders the integrated events (SFX bus capture,
  limiter included) to `build/qa_m8.8-02/audition/*.wav` + `INDEX.md` for desktop
  listening / technical review.
- `tools/audio_qa.tscn` — interactive dev scene, every event on a button.
- `tools/audio_probe.gd` — per-file peak/RMS/silence measurement through the engine.

## 7. Out of scope / not done here

Background music (v1 non-goal), container sway and any new VFX (post-launch backlog,
owner decision), native haptic plugin (non-goal), A36 device gate (next step, needs
explicit authorisation).
