# MERGE_SOUND_FAMILY.md — the merge family as implemented (M8.8-02, canonical)

**Owner decision: A — premium direction** (listening pass on the M8.8-01.1 shortlist):
*soft pop/body → small glass/chime escalation → Tier 8 bell bloom + music-box note +
short twinkle tail. Tier 8 wider / longer / more special, not louder.*

This file describes what `AudioManager.play_merge(tier)` actually does on
`task/032-production-audio-integration`. Numbers are copied from `MERGE_RECIPE` and
`EVENTS` in `scripts/autoload/audio_manager.gd`; `tools/audio_test` asserts the
structure (bands, thresholds, layer counts, offsets). The M8.8-01 blueprint
(`build/qa_m8.8-01/MERGE_SOUND_FAMILY_BLUEPRINT.md`) was the proposal; this is the result.

## 1. Principle

Four materials, not eight sounds. Every tier is the same family at a different size:

| layer | what it is | source (owner label) | production files | active tiers |
|---|---|---|---|---|
| **POP** | tonal "blup" core, pitched per tier | `Cartoon Bubbles Short.wav` — Sonniss · Cinematic Sound Design (BODY A) | `sfx_merge_pop_01/02.wav` — the two bubbles inside the source, RMS-matched (peaks −6.5 / −3.0 dBFS) | T1–T8 |
| **BODY** | dry dough body under the pop, three tier-banded pools | Kenney Impact `impactGeneric_light_002/004` (BODY B) · `impactPlate_light_003` + `impactPlate_medium_001` (BODY C / LARGE BODY B) · `impactPunch_medium_001` (LARGE BODY A) | `sfx_merge_body_light_01/02` · `sfx_merge_body_full_01/02` · `sfx_merge_body_large_01` | light T1–T3 · full T4–T6 · large T7–T8 |
| **SPARKLE** | tiny glass tick, +30 ms after the body | Kenney Impact `impactGlass_light_002/000/004` (SPARKLE A) | `sfx_merge_sparkle_01/02/03.wav` | T3–T7 |
| **CHIME** | soft 226 Hz bell, +45 ms | Kenney Impact `impactBell_heavy_002` (CHIME T5-7) | `sfx_merge_chime_01.wav` | T5–T7 |
| **BLOOM** | warm 380 Hz bell, 1.1 s, +20 ms | Kenney Impact `impactBell_heavy_000` (T8 BLOOM A) | `sfx_tier8_bloom_01.wav` | T8 |
| **BOX** | one music-box note (~945 Hz), +70 ms | Sonniss · Sonic Bat `SBmb_Music Box A 013.wav`, first 0.55 s (T8 BLOOM B) | `sfx_tier8_box_01.wav` | T8 |
| **TAIL** | short rising twinkle, +120 ms | Sonniss · Cinematic Sound Design `Button Arp Twinkle.wav`, first 0.6 s (T8 TAIL A) | `sfx_tier8_tail_01.wav` | T8 |

At T8 the sparkle and chime are **replaced** by bloom + box + tail (the bloom is the
same bell family as the chime; the tail is the same glassy register as the sparkle),
so T8 stays at five voices: POP + large BODY + BLOOM + BOX + TAIL.

## 2. Exact per-tier composition (`MERGE_RECIPE`)

POP pitch is the locked escalation `TierConfig.merge_pitch(t) = 0.85 + 0.09·(t−1)`
(0.85 → 1.48, GAME_DESIGN §6) — applied to the POP only. Body / sparkle / chime
values below are absolute `volume_db` on the voice (they replace the pool's table
`gain_db`); every layer also gets its pool's jitter (see §4).

| tier | POP dB | body pool | body pitch | body dB | sparkle pitch / dB (+30 ms) | chime pitch / dB (+45 ms) | T8 layers | voices |
|---|---|---|---|---|---|---|---|---|
| T1 | −3 | `merge_body_light` | 1.15 | −16 | — | — | — | 2 |
| T2 | −2 | `merge_body_light` | 1.08 | −14 | — | — | — | 2 |
| T3 | −1 | `merge_body_light` | 1.00 | −12 | 1.00 / −14 | — | — | 3 |
| T4 | −1 | `merge_body_full` | 0.95 | −10 | 1.06 / −12 | — | — | 3 |
| T5 | −1 | `merge_body_full` | 0.90 | −8 | 1.06 / −12 | 1.00 / −11 | — | 4 |
| T6 | −1 | `merge_body_full` | 0.84 | −8 | 1.12 / −11 | 1.06 / −9 | — | 4 |
| T7 | −1 | `merge_body_large` | 0.90 | −7 | 1.12 / −11 | 1.12 / −8 | — | 4 |
| T8 | −3 | `merge_body_large` | 0.80 | −7 | — | — | BLOOM −7 dB @ +20 ms · BOX −10 dB @ +70 ms · TAIL −14 dB @ +120 ms | 5 |

Reading the progression against the brief:

- **T1** very soft body/pop — POP 2 dB under the rest, light body at −16 dB, no sparkle:
  the first merges are the quietest thing on the board.
- **T2** same family, slightly fuller (body −14 dB, 1.08×).
- **T3** first tiny sparkle (glass at −14 dB, 30 ms after the body so the body reads
  first and the glass reads as "shine").
- **T4** fuller body: the plate pool enters at 0.95×.
- **T5** chime enters gently (bell −11 dB, 45 ms).
- **T6** stronger body + chime (chime +2 dB and one semitone up).
- **T7** larger warm body (punch pool, 0.90×) + controlled sparkle (glass still −11 dB).
- **T8** warm bloom + music-box note + short twinkle tail. POP is turned *down* 2 dB
  and the large body sits at −7 dB — the first 50 ms of a T8 measures −14 dBFS in the
  rendered bundle, i.e. the same as a T5–T6 merge; what makes it special is the
  0.9 s of bloom/box/tail after it (T7 is silent after ~0.4 s).

Measured in the integrated render (`build/qa_m8.8-02/audition/`, 50 ms RMS of the first
window / whole-file peak): T1 −17 / −5.2 · T2 −16 / −5.4 · T3 −13 / −6.0 ·
T4 −13 / −3.5 · T5 −14 / −6.0 · T6 −14 / −4.3 · T7 −12 / −2.5 · T8 −14 / −6.2 dBFS.
T8 never touches the SFX limiter.

## 3. Timing

All offsets are measured from the merge call (`_resolve_merge` or the Büyütücü
transform), scheduled with `SceneTreeTimer`s inside `AudioManager` (no process loop).

| layer | offset | why |
|---|---|---|
| POP, BODY | 0 ms | the physical impact; the haptic pulse (if any) aligns with this |
| SPARKLE | +30 ms | "shine" after the body transient, not a second transient |
| CHIME | +45 ms | bell after the body, before the sparkle has decayed |
| BLOOM | +20 ms | opens right after the pop/body strike |
| BOX | +70 ms | the note sits inside the opening bloom |
| TAIL | +120 ms | twinkle over the bloom's decay |

T8 total ≈ 1.2 s (bloom 1.1 s from +20 ms); every other tier is finished within
≈ 0.5 s (chime tail). The SPECIAL haptic's two pulses (35 ms at 0, 60 ms at +95 ms)
land on the pop/body strike and on the opening bloom/box — see HAPTIC_MAPPING.md.

## 4. Variation and replay-fatigue guards

- POP: 2 variants (the two bubbles of the one approved source), ±2 % pitch, ±1 dB.
- BODY light / full: 2 variants each, ±1 dB; large: 1 file, ±1 dB.
- SPARKLE: 3 sibling files, ±3 % pitch, ±1 dB. CHIME: ±0.5 dB.
- Nothing below T8 has a tail longer than the 0.5 s chime; T1–T4 are ≤ 0.3 s.
- No musical phrase on any normal merge; the music-box note appears only at T8 (once
  per T8, cooldown 300 ms on the whole T8 tree; two T8 stacks may overlap — `max_voices`
  2 on bloom/box/tail since the M8.8-02.1 device gate — a third inside the 1.1 s bloom is dropped).
- Combo (`play_combo`) is the same glass tick at −11 dB with the existing +4 %/step
  pitch — a sweetener, not a melody.
- Voice caps: POP 4 (steal oldest), bodies 3/3/2, sparkle 3, chime 2 — a fast chain
  never stacks more than that; cooldown 30 ms on POP/body/sparkle, 60 ms on the chime.

## 5. Phone-speaker requirement

M8.8-01 measured the previous body (`impactSoft_medium_000`) at 100 % of its energy
below 200 Hz — inaudible on the A36 speaker. The production bodies keep their
midrange (share of spectral power in 250 Hz–3 kHz, measured on the delivered files):
light bodies 100 %, plate_light 56 %, plate_medium 33 % (51 % below 200 Hz — its
warmth is on headphones, it still has a real midrange), punch 74 %. The large body
never goes below 0.80× (0.70× would have pushed the punch under 150 Hz). Nothing was
brightened: high-passes are 100–120 Hz (bodies) / 150 Hz (bells), low-passes 6 kHz
(punch) / 8 kHz (glass, tail).

## 6. Processing applied to the family sources (offline, once)

| source | trim | filters | fades | note |
|---|---|---|---|---|
| Cartoon Bubbles Short | 0–0.200 s and 0.215–0.500 s | HP 120 Hz | 2 / 30–40 ms | two natural bubbles → two POP variants, RMS-matched |
| impactGeneric_light_002 / 004 | whole (0.14 s) | HP 100 Hz | 2 / 20 ms | |
| impactPlate_light_003, impactPlate_medium_001 | 0–0.35 s | HP 120 Hz | 2 / 60 ms | |
| impactPunch_medium_001 | 0–0.40 s | HP 110 Hz, LP 6 kHz | 2 / 60 ms | |
| impactGlass_light_002 / 000 / 004 | whole | LP 8 kHz | 2 / 30 ms | |
| impactBell_heavy_002 | 0–0.50 s | HP 150 Hz | 2 / 80 ms | |
| impactBell_heavy_000 | 0–1.10 s | HP 150 Hz | 2 / 120 ms | |
| SBmb_Music Box A 013 | 0–0.55 s (the first note only) | LP 10 kHz | 2 / 150 ms | |
| Button Arp Twinkle | 0–0.60 s | LP 8 kHz | 2 / 100 ms | 37 % of its energy is still above 4 kHz — bright by design, mixed at −14 dB |

Common chain: mono → 44.1 kHz windowed-sinc → filters → head trim (≤ 1 ms) → tail
trim → fades → peak −4 dBFS → 16-bit with TPDF dither (`tools/audio_production_build.py`).

## 7. Other paths that use the family

- **Büyütücü** (owner C): `upgrade` riser at the tap → 150 ms gameplay anticipation
  (unchanged) → `upgrade_transform` (airy sweep, −14 dB) + `play_merge(new_tier)` at
  the actual transform. T7→T8 through Büyütücü therefore produces exactly the T8 stack
  above (asserted by the test) plus the SPECIAL haptic.
- **Endless annihilation** (8 + 8): the large body at 0.75× / −3 dB with the whole
  `tier_max` tree (bloom / box / tail) layered on top; STRONG haptic.
- **Rewards** reuse the T8 layers as the "premium" register: Rare = TAIL; Epic = BOX +
  TAIL (+60 ms); Legendary = BLOOM + BOX (+60 ms) + BOX a fourth up at 1.335× (+220 ms)
  + TAIL (+120 ms). Result stars = SPARKLE at +12 %/star; level unlock = TAIL.

## 8. Rationale (short)

- One family across eight tiers keeps hundreds of merges per session coherent; size is
  communicated by body weight, pitch and the number of layers, not by loudness.
- Glass at T3 gives the mid-game a reward without a musical phrase; the bell at T5 marks
  "the dumpling got heavier"; T8 is the only place a music-box note is allowed.
- Delayed layers (+30/+45 ms) make the merge read as one event with a shimmer instead
  of two simultaneous transients.
- The haptic mapping follows the body: nothing at T1–T3 (constant), LIGHT at T4–T5
  (full body enters), MEDIUM at T6–T7 (large body), SPECIAL at T8 (bloom).
