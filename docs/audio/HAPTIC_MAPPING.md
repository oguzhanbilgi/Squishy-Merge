# HAPTIC_MAPPING.md — vibration mapping as implemented (M8.8-02, canonical)

This is the **actual runtime behaviour** of `scripts/haptics.gd` and its call sites on
`task/032-production-audio-integration`. `tools/audio_test` asserts the merge mapping
tier by tier, the dictionary durations, the spam window and (by source scan) every
power call site.

## 1. Dictionary (`Haptics`)

| level | platform call | duration | amplitude (Android with amplitude control) |
|---|---|---|---|
| LIGHT | `Input.vibrate_handheld` | 18 ms | 0.35 |
| MEDIUM | `Input.vibrate_handheld` | 32 ms | 0.65 |
| STRONG | `Input.vibrate_handheld` | 55 ms | 1.00 |
| SPECIAL | two pulses | 35 ms, 60 ms gap, 60 ms | 1.00 / 1.00 |

No pulse is longer than 60 ms. Editor / desktop: `is_supported()` is false, no platform
call is made, every request returns false. Settings → Titreşim (`haptics_enabled`, default
on) gates everything through `Haptics.set_enabled`.

## 2. Normal merge — owner direction (changed in M8.8-02)

`GameBoard._resolve_merge` → `Haptics.merge_tier(new_tier)`:

| result tier | haptic | constant |
|---|---|---|
| T1 | **none** | `tier < MERGE_LIGHT_MIN_TIER` |
| T2 | **none** | |
| T3 | **none** | |
| T4 | LIGHT (18 ms) | `MERGE_LIGHT_MIN_TIER = 4` |
| T5 | LIGHT (18 ms) | |
| T6 | MEDIUM (32 ms) | `MERGE_MEDIUM_MIN_TIER = 6` |
| T7 | MEDIUM (32 ms) | |
| T8 | SPECIAL (35 + 60 ms) | `TierConfig.MAX_TIER` |

Previous runtime (M8.5-15 → M8.7-02): T1–T5 LIGHT, T6–T7 MEDIUM, T8 SPECIAL. The owner
moved the floor up because early merges happen constantly, the game's identity is
relaxing, the escalation should communicate size, and vibration fatigue matters.
T1–T3 do not even enter the spam window (`request_count` stays 0), so a T4 merge right
after a T3 still pulses.

Combo does **not** vibrate separately (the merge carries it).

## 3. Powers and other events (unchanged)

| event | haptic | where |
|---|---|---|
| Bomba | STRONG at impact only; nothing during flight | `_detonate_bomb` |
| Büyütücü | MEDIUM at the transform; SPECIAL when the resulting tier is T8 (same class as a T7+T7 merge) | `_finish_upgrade` |
| Sarsıntı | MEDIUM once | `_use_shake` |
| Temizleyici | LIGHT once at activation; never per removed piece | `_use_clear_small` (not `_pop_and_free`) |
| Endless annihilation (8+8) | STRONG | `_resolve_annihilation` |
| Overflow (fail moment) | MEDIUM once | overflow → revive offer |
| Revive granted | MEDIUM | `grant_revive` |
| Drop, landing, danger tick, combo count, round win/lose | none | — |
| Purchase / refill | MEDIUM | shop, refill |
| Skin equipped | LIGHT | collection |
| Insufficient Hamur (shop) | LIGHT | shop |
| Vibration toggle switched on | MEDIUM (confirmation) | settings |
| Reward reveal | Legendary SPECIAL · Epic MEDIUM · skin reward MEDIUM · Hamur LIGHT | round result |

No haptic event was added in M8.8-02.

## 4. Spam window (`MIN_GAP_MS = 70`, unchanged)

Inside 70 ms of the previous pulse only a **stronger** pulse gets through; equal or
weaker requests are suppressed (`suppressed_count`). Twenty rapid LIGHT requests give
one pulse; a STRONG after a LIGHT within the window still fires; SPECIAL's second pulse
is scheduled by a `SceneTreeTimer` and is not subject to the window.

## 5. Audio / haptic alignment

Haptics align with the **body / physical impact** layer; sparkle, chime, bloom, box and
tail are audio only.

- Merge T4–T7: the single pulse fires in the same frame as POP + BODY (offset 0 ms);
  the +30/+45 ms sparkle/chime have no pulse.
- Merge T8 (and Büyütücü → T8): SPECIAL pulse 1 (35 ms) with the POP / large body
  strike; pulse 2 (60 ms) at +95 ms — inside the opening bloom (+20 ms) and the
  music-box note (+70 ms), before the tail (+120 ms). Measured in the integrated render:
  pulses at +0 and +94 ms, bloom/box/tail at +20/+70/+120 ms.
- Bomba: STRONG with `bomb_impact` (0 ms); the +15 ms poof carries no pulse.
- No gameplay timing was changed to make audio and haptics align.

## 6. Tests

`tools/audio_test.tscn` — "merge T1…T8 titreşim" (eight explicit checks, sink-captured
durations), T1–T3 do not fill the window, dictionary ≤ 60 ms, `MIN_GAP_MS` 70, enabled
/ supported gates, SPECIAL two pulses, call-site scan for every power.
`tools/gameplay_feedback_test.tscn` — real board: T4 merge LIGHT, T7+T7 SPECIAL,
Büyütücü T3→T4 MEDIUM and T7→T8 SPECIAL, Sarsıntı single MEDIUM.
