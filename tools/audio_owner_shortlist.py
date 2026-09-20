#!/usr/bin/env python
"""audio_owner_shortlist.py — M8.8-01.1 owner audition shortlist (~43 files).

Cuts the 164-entry audit pool (tools/audio_audition_export.py) down to the
deliberate set the owner actually listens to, and writes — OUTSIDE the
production asset tree —

    build/qa_m8.8-01/owner_shortlist/<NN>_<ROLE>__<original stem>.wav
        gain-matched listening copies (silence trim + 2/15 ms fades +
        common RMS, 16-bit PCM at the original sample rate / channels;
        NO compression, NO EQ, NO trims of the sound itself — the owner must
        hear the source character). File numbers follow the listening order.
    build/qa_m8.8-01/owner_shortlist/owner_shortlist_index.csv
        provenance (pack / library / source path / licence) + measurements
    build/qa_m8.8-01/OWNER_LISTENING_GUIDE.md
    build/qa_m8.8-01/M8.8-01_OWNER_AUDIO_SHORTLIST.zip   (with --zip)

Selection rule (M8.8-01.1 §2): metrics only REJECT obvious problems
(inaudible on phone, sub-bass dependence, harsh high spike, excessive length,
clipping, malformed file); everywhere taste matters, real alternatives are
kept. `share_250_3k` = fraction of spectral power between 250 Hz and 3 kHz —
the phone-speaker band — reported, not optimised for.

Requires the same isolated venv as the audit (numpy + soundfile) and the
inventory JSON from tools/audio_source_audit.py. Nothing here touches the
Godot project, assets/ or the runtime.
"""
from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import zipfile
from pathlib import Path

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True  # no tools/__pycache__ in the repo
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_audition_export import PEAK_CEILING_DBFS, TARGET_RMS_DBFS, normalise  # noqa: E402

SOURCE_DEFAULT = r"D:\dev\squishy-audio-source"
OUT_DEFAULT = "build/qa_m8.8-01"
BUNDLE_DOCS = ["OWNER_LISTENING_GUIDE.md", "FINAL_AUDIO_PALETTE.md",
               "MERGE_SOUND_FAMILY_BLUEPRINT.md", "AUDIO_SOURCE_PROVENANCE.md"]

# fmt: off
# num, code, filename, section, roles (primary first), merge-family label,
# listen-for note, flags.  One physical file per entry; shared roles are
# cross-referenced in the guide instead of duplicating the file.
OWNER_SHORTLIST: list[dict] = [
    # ---- 1. MERGE BODY (5) ----
    {"num": 1, "code": "MERGE_BODY_A", "file": "Cartoon Bubbles Short.wav", "section": "merge_body",
     "roles": ["merge POP core, tiers 1-4 (pitch-escalated)"], "family": "BODY A",
     "note": "Role: the tonal 'blup' pop every merge is built on; survives repetition because it is a pure tone (no noise burst) that pitch/gain jitter can vary and it will be trimmed to ~0.3 s; survives a phone because {pb} of its energy sits in the 250 Hz-3 kHz speaker band (centroid 390 Hz).",
     "listen": "Is this a gentle bubble or a cartoon 'bloop'? If cartoon, BODY B/C alone become the pop.", "flags": ["TRIM"]},
    {"num": 2, "code": "MERGE_BODY_B", "file": "impactGeneric_light_002.ogg", "section": "merge_body",
     "roles": ["dry soft body under the pop, tiers 1-3"], "family": "BODY B",
     "note": "Role: the dry dough body under the pop for small tiers; survives repetition because it is 0.14 s with a ~0 dB/10 ms onset (no click) and nothing above 4 kHz; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (centroid 614 Hz).",
     "listen": "Soft thud vs. 'tap' — does it feel like dough or like tapping a table?", "flags": []},
    {"num": 3, "code": "MERGE_BODY_C", "file": "impactPlate_light_003.ogg", "section": "merge_body",
     "roles": ["warmer / fuller body, tiers 3-4"], "family": "BODY C",
     "note": "Role: the warmer, fuller body step for tiers 3-4; survives repetition because its 55 ms decay never overlaps the next merge and the onset is 27 dB/10 ms (rounded); survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (centroid 812 Hz) — the warmest plate that still keeps a real midrange; the rest is the low warmth a phone will thin.",
     "listen": "Warm and round, or 'ceramic'? Compare directly with 02.", "flags": []},
    {"num": 4, "code": "MERGE_BODY_D", "file": "impactPlate_medium_001.ogg", "section": "merge_body",
     "roles": ["fuller body, tiers 5-6", "LARGE BODY B (alternate to 20)"], "family": "LARGE BODY B",
     "note": "Role: the fuller plate body for tiers 5-6 and the alternate large body; survives repetition because large-tier merges are rarer and its decay is 55 ms; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (centroid 682 Hz) — deeper than 03 without going sub-only.",
     "listen": "Does 'bigger' read as warmer, not just louder? Compare with 20.", "flags": []},
    {"num": 5, "code": "MERGE_BODY_E", "file": "drop_003.ogg", "section": "merge_body",
     "roles": ["designed tonal pop (alternate to 01)"], "family": None,
     "note": "Kenney Interface 'drop': a clean designed 727 Hz blip, 0.09 s effective, no transient — the 'digital candy' alternative to the recorded bubble/impacts.",
     "listen": "Cheap-UI or cute? It is here so the recorded-vs-designed choice is a real one.", "flags": []},

    # ---- 2. SPARKLE / CHIME (4) ----
    {"num": 10, "code": "SPARKLE_A", "file": "impactGlass_light_002.ogg", "section": "sparkle",
     "roles": ["tiny glass tick from tier 3 (+30 ms after body)", "star reveal", "T8 TAIL fallback (3 stepped ticks, no new file)"], "family": "SPARKLE A",
     "note": "Role: the tiny glass sparkle that enters at tier 3; survives repetition because it is 0.12 s effective with 0 % energy above 4 kHz and has two sibling variants (_000/_004) in the pool; survives a phone because {pb} of its energy is a ~1.1 kHz tone inside the speaker band.",
     "listen": "Tiny and pretty, or 'clink'? Imagine it 100 times at −14 dB.", "flags": []},
    {"num": 11, "code": "SPARKLE_B", "file": "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav", "section": "sparkle",
     "roles": ["warm organic chime (combo sweetener, tier 5-7 chime alternative)", "T8 TAIL B (alternate to 23)", "level unlock"], "family": "SPARKLE B (+ T8 TAIL B)",
     "note": "Role: the warm organic alternative to glass — combo sweetener and the tail under a T8 bloom; survives repetition because it is two soft plucks (21 dB/10 ms onset) with no tail past 0.36 s; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (the 23 % above 4 kHz would be low-passed later).",
     "listen": "Cute-premium or 'world music'? Kalimba is the only organic chime in the library.", "flags": []},
    {"num": 12, "code": "SPARKLE_C", "file": "glass_001.ogg", "section": "sparkle",
     "roles": ["softer glass ting with tail, tiers 5-7"], "family": None,
     "note": "Kenney Interface glass: ~1.9 kHz, 0.28 s, 90 ms decay, 0 % above 4 kHz — the longer, gentler shimmer for higher tiers.",
     "listen": "Gentle shimmer vs. wine-glass 'ting'.", "flags": []},
    {"num": 13, "code": "SPARKLE_D_CHIME", "file": "impactBell_heavy_002.ogg", "section": "sparkle",
     "roles": ["soft bell chime from tier 5 ('lower warm body + chime')"], "family": "CHIME (T5-7)",
     "note": "Role: the soft 226 Hz bell chime that marks tiers 5-7; survives repetition because it is a single pure bell hit (17 dB/10 ms) with a 95 ms decay, no melody; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (the bell's overtones; its 226 Hz fundamental sits just under it).",
     "listen": "Warm 'bong' or church bell? It should feel like the dumpling got heavier, not like a notification.", "flags": []},

    # ---- 3. LARGE MERGE / T8 (4) ----
    {"num": 20, "code": "LARGE_BODY_A", "file": "impactPunch_medium_001.ogg", "section": "large_t8",
     "roles": ["low warm body, tiers 6-8", "Bomba impact body layer", "endless annihilation body"], "family": "LARGE BODY A",
     "note": "Role: the low warm 'wumm' body for tiers 6-8 (and under the Bomba hit); survives repetition because it is compact (0.21 s effective, 30 dB/10 ms onset) and big merges are rare; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (centroid 198 Hz) — the only low hit in the library that keeps roughly half its energy where a phone can play it.",
     "listen": "Warm weight, or a punch? It must not feel aggressive.", "flags": []},
    {"num": 21, "code": "T8_BLOOM_A", "file": "impactBell_heavy_000.ogg", "section": "large_t8",
     "roles": ["tier-8 warm bell bloom (+20 ms after body)"], "family": "T8 BLOOM A",
     "note": "Role: the warm bell bloom that makes tier 8 wider (not louder); survives repetition because T8 happens at most a few times per round and the bell has no melody and a 21 dB/10 ms onset; survives a phone because its 380 Hz fundamental and {pb} of its energy sit in the 250 Hz-3 kHz speaker band.",
     "listen": "Premium warmth or 'gong'? 1.5 s long — the proposed trim is 1.1 s.", "flags": ["LONG"]},
    {"num": 22, "code": "T8_BLOOM_B", "file": "SBmb_Music Box A 013.wav", "section": "large_t8",
     "roles": ["tier-8 music-box note (alternate bloom or +70 ms chime layer)", "Legendary reward alternate"], "family": "T8 BLOOM B",
     "note": "Role: the cute-premium music-box alternative to the bell (or its +70 ms chime layer); survives repetition only if trimmed to its first note — a full phrase on every T8 becomes a jingle; survives a phone because {pb} of its energy is in the 250 Hz-3 kHz speaker band (~945 Hz).",
     "listen": "You hear the whole 2.8 s phrase here; judge the FIRST note. Cute or nursery?", "flags": ["TRIM", "LONG"]},
    {"num": 23, "code": "T8_TAIL_A", "file": "Button Arp Twinkle.wav", "section": "large_t8",
     "roles": ["tier-8 sparkle tail (+120 ms, trimmed to 0.6 s)", "skin unlock reveal"], "family": "T8 TAIL A",
     "note": "Role: the short rising sparkle tail after the bloom (and the skin-unlock cue); survives repetition because it is trimmed to 0.6 s, sits at −14 dB and T8 is rare; on a phone only {pb} of its energy is in the 250 Hz-3 kHz band and 48 % is above 4 kHz — bright by design, so it would be low-passed at 8 kHz and kept quiet (flag).",
     "listen": "Magical or 'slot machine'? If it tips into casino, 11 (kalimba) takes the tail.", "flags": ["BRIGHT", "TRIM"]},

    # ---- 4. DROP (3) ----
    {"num": 30, "code": "DROP_A", "file": "footstep_carpet_000.ogg", "section": "drop",
     "roles": ["landing 'puf' (event `land`, pitch by tier, gain by speed)"], "family": None,
     "note": "0.14 s cloth puf, centroid 445 Hz, {pb} in the phone band, 12 dB/10 ms onset; its sibling _003 (lighter) is in the pool as the natural variant.",
     "listen": "Soft 'puf' or footstep? This plays every 0.4 s — it must be the least interesting sound in the game.", "flags": []},
    {"num": 31, "code": "DROP_B", "file": "FOLYClth_SinglePats04_InMotionAudio_FoleyT-Shirt.wav", "section": "drop",
     "roles": ["landing 'plop', fuller (alternate to 30)"], "family": None,
     "note": "Cloth pat, centroid 388 Hz, {pb} in the phone band (64 % below 200 Hz — fuller but a phone will thin it), 0.25 s effective; would be trimmed to ~0.2 s.",
     "listen": "More 'dough' than 30, or more 'fabric'?", "flags": ["TRIM"]},
    {"num": 32, "code": "DROP_C", "file": "impactGeneric_light_001.ogg", "section": "drop",
     "roles": ["landing: rounded light tap (alternate)"], "family": None,
     "note": "0.12 s, centroid 581 Hz, {pb} in the phone band, 1 dB/10 ms onset — the roundest, driest option.",
     "listen": "Rounded and neutral, or too 'tap'?", "flags": []},

    # ---- 5. POWERS: BOMBA (3) ----
    {"num": 40, "code": "BOMBA_LAUNCH", "file": "minimize_006.ogg", "section": "bomba",
     "roles": ["Bomba flight (0.28 s): falling tone 603→269 Hz", "modal close alternate"], "family": None,
     "note": "Pure tonal descent, 0.38 s, {pb} in the phone band; distinct from the noisy sweeps the other powers use.",
     "listen": "Does 'falling' read without being a cartoon slide-whistle?", "flags": []},
    {"num": 41, "code": "BOMBA_IMPACT", "file": "impactPunch_medium_000.ogg", "section": "bomba",
     "roles": ["Bomba hit: compact 'pop-bum' (over LARGE BODY A)"], "family": None,
     "note": "0.43 s, centroid 182 Hz, {pb} in the phone band, 23 dB/10 ms — compact, not an explosion.",
     "listen": "Satisfying thump vs. aggressive hit.", "flags": []},
    {"num": 42, "code": "BOMBA_POOF", "file": "footstep_snow_000.ogg", "section": "bomba",
     "roles": ["Bomba soft 'poof' layer (+15 ms, −8 dB)", "landing alternate with texture"], "family": None,
     "note": "0.37 s puf with a little crunch, centroid 504 Hz, {pb} in the phone band.",
     "listen": "Adds 'poof' softness to 41, or sounds like snow?", "flags": []},

    # ---- 5. POWERS: BÜYÜTÜCÜ (4) ----
    {"num": 50, "code": "BUYUTUCU_CHARGE", "file": "maximize_006.ogg", "section": "buyutucu",
     "roles": ["Büyütücü charge at the tap (0.15 s anticipation): rising tone 269→603 Hz", "modal open alternate"], "family": None,
     "note": "Pure tonal riser, 0.38 s, {pb} in the phone band — the 'loading up' pitch lift.",
     "listen": "Magical lift or 'power-up arcade'?", "flags": []},
    {"num": 51, "code": "BUYUTUCU_AIR", "file": "Woosh Sweep Slide Infographics Basic.wav", "section": "buyutucu",
     "roles": ["airy rising whoosh under the charge (−12 dB)", "Temizleyici sweep alternate (whichever power keeps it, the other takes 70)"], "family": None,
     "note": "562→1629 Hz airy sweep, 0.50 s, {pb} in the phone band, flatness 0.12 (light noise, not a jet).",
     "listen": "Light and airy, or a 'whoosh' from a trailer? Only one power should own it.", "flags": []},
    {"num": 52, "code": "BUYUTUCU_TRANSFORM_A", "file": "Interface Plucks Happy.wav", "section": "buyutucu",
     "roles": ["Büyütücü transform: warm plucks (~150 ms after charge)", "Rare reward / skin equip alternate"], "family": None,
     "note": "967→1283 Hz plucks, 0.85 s, {pb} in the phone band, tonal — shimmer without glass.",
     "listen": "'Became bigger' with warmth, or a ringtone?", "flags": []},
    {"num": 53, "code": "BUYUTUCU_TRANSFORM_B", "file": "Game Entry Happy Short.wav", "section": "buyutucu",
     "roles": ["Büyütücü transform alternate: warm two-note", "WIN alternate (non-jingle)", "Epic reward"], "family": None,
     "note": "445→1043 Hz two-note, 0.88 s, {pb} in the phone band, 12 dB/10 ms — a purpose-built casual 'yay'.",
     "listen": "Friendly 'ta-da' or level-up arcade? Same question for its WIN use.", "flags": []},

    # ---- 5. POWERS: SARSINTI (3) — category still weak ----
    {"num": 60, "code": "SARSINTI_A", "file": "Vibrato Impact Snap Spin Transition.wav", "section": "sarsinti",
     "roles": ["Sarsıntı: jelly wobble (first ~0.45 s)"], "family": None,
     "note": "The only wobble in the library — but only {pb} of its energy is in the phone band (85 % below 200 Hz) and it is 3.2 s long; you hear the whole file here, judge the first half second.",
     "listen": "Jelly wobble or cinematic bass? Would it survive a phone speaker?", "flags": ["PHONE", "TRIM", "LONG"]},
    {"num": 61, "code": "SARSINTI_B", "file": "impactPlate_medium_003.ogg", "section": "sarsinti",
     "roles": ["Sarsıntı: short low warm pulse"], "family": None,
     "note": "0.57 s, centroid 177 Hz, only {pb} in the phone band — the honest 'wumm', mostly sub on a phone.",
     "listen": "Warm pulse, or just a thud that the phone will drop?", "flags": ["PHONE"]},
    {"num": 62, "code": "SARSINTI_C", "file": "Cartoon Transition Bass Down.wav", "section": "sarsinti",
     "roles": ["Sarsıntı: descending down-wobble (first ~0.7 s)"], "family": None,
     "note": "568→190 Hz descent, {pb} in the phone band (phone-safe), 3.5 s long — would be trimmed to the first 0.7 s.",
     "listen": "Cozy wobble-down, or too cartoon? Judge the first second only.", "flags": ["TRIM", "LONG"]},

    # ---- 5. POWERS: TEMİZLEYİCİ (3) ----
    {"num": 70, "code": "TEMIZLEYICI_SWEEP", "file": "Cartoon Pull Swoosh Readout.wav", "section": "temizleyici",
     "roles": ["Temizleyici broom sweep (first ~0.4 s)", "Büyütücü air alternate"], "family": None,
     "note": "Rising +11 st swoosh, centroid 986 Hz, {pb} in the phone band, 2.3 s long — first 0.4 s is the sweep; 51 is the other sweep option.",
     "listen": "Soft broom or cartoon 'zip'? Judge the start.", "flags": ["TRIM", "LONG"]},
    {"num": 71, "code": "TEMIZLEYICI_POPS", "file": "Cartoon Pops Random Sequence Reverb.wav", "section": "temizleyici",
     "roles": ["Temizleyici pop cascade under the sweep (or sliced into single pops)"], "family": None,
     "note": "1.4 s of small ~900 Hz pops with light reverb, {pb} in the phone band.",
     "listen": "Popcorn-cute, or too many / too wet (reverb)?", "flags": ["TRIM"]},
    {"num": 72, "code": "TEMIZLEYICI_POP", "file": "select_001.ogg", "section": "temizleyici",
     "roles": ["Temizleyici single pop per piece (±8 % pitch, 45 ms cooldown)"], "family": None,
     "note": "0.04 s tick at 2.3 kHz, {pb} in the phone band — becomes popcorn through the existing jitter/cooldown.",
     "listen": "Imagine 10 of these in 0.5 s: playful or clicky?", "flags": []},

    # ---- 6. DANGER (2) ----
    {"num": 80, "code": "DANGER_A", "file": "bong_001.ogg", "section": "danger",
     "roles": ["danger tick every 0.5 s (−10 dB)"], "family": None,
     "note": "0.12 s pure 237 Hz 'bong', no transient — repeatable twice a second without becoming a siren, BUT its tone sits just under the speaker band (only {pb} in 250 Hz-3 kHz): at −10 dB on the A36 it may all but vanish; 81 is the phone-safe alternative.",
     "listen": "Loop it in your head at 0.5 s: tension or annoyance? Also try it on the phone speaker.", "flags": ["PHONE"]},
    {"num": 81, "code": "DANGER_B", "file": "question_004.ogg", "section": "danger",
     "roles": ["danger two-note descending warning (alternate)"], "family": None,
     "note": "495→334 Hz two-note, 0.33 s, tonal, {pb} in the phone band — the spec's 'soft two-note'.",
     "listen": "Gentle 'uh-oh' or a quiz-show cue?", "flags": []},

    # ---- 7. WIN / FAIL (4) ----
    {"num": 90, "code": "WIN_A", "file": "jingles_PIZZI04.ogg", "section": "win_fail",
     "roles": ["round win: short rising pizzicato", "revive at 0.9× (alternate)"], "family": None,
     "note": "221→371 Hz (+9 st), 0.56 s, {pb} in the phone band — same instrument as the fail stings so the round-state language is one voice.",
     "listen": "Cute and short, or 'level complete' arcade?", "flags": []},
    {"num": 91, "code": "WIN_B", "file": "jingles_STEEL09.ogg", "section": "win_fail",
     "roles": ["round win: steel-drum riser (different colour)"], "family": None,
     "note": "334→592 Hz (+10 st), 0.59 s, {pb} in the phone band — warm tropical alternative; 53 is the non-jingle option.",
     "listen": "Cozy or beach-bar?", "flags": []},
    {"num": 92, "code": "FAIL_A", "file": "jingles_PIZZI05.ogg", "section": "win_fail",
     "roles": ["overflow / fail moment: descending pizzicato", "round lose alternate"], "family": None,
     "note": "371→221 Hz (−9 st), 0.54 s — the mirror of 90.",
     "listen": "'Hayır ya' with a smile, or sad?", "flags": []},
    {"num": 93, "code": "FAIL_B", "file": "jingles_PIZZI00.ogg", "section": "win_fail",
     "roles": ["round lose: softer descending pizzicato"], "family": None,
     "note": "463→312 Hz (−7 st), 0.49 s, the quietest pizzicato (−6 dBFS peak).",
     "listen": "Gentler than 92? One of the two takes 'fail moment', the other 'round lose'.", "flags": []},

    # ---- 8. CHEST / REWARD / SKIN (4) — chest category still weak ----
    {"num": 100, "code": "CHEST_OPEN_A", "file": "MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav", "section": "rewards",
     "roles": ["chest open: latch click + thunk"], "family": None,
     "note": "0.38 s, click + body ({pb} in the phone band, 20 % > 4 kHz) — reads 'unlocks', but it is a mechanical latch, not candy.",
     "listen": "Does a latch fit a candy chest at all? If not, say so — we source one sound.", "flags": ["WEAK"]},
    {"num": 101, "code": "CHEST_OPEN_B", "file": "CLOTHFlp_Action Inventory Open Flip Cloth Canvas Bag Slide Light 02_ESM_FG2.wav", "section": "rewards",
     "roles": ["chest open: soft cloth lid (alternate)"], "family": None,
     "note": "0.69 s soft cloth flip, {pb} in the phone band, noisy (flatness 0.27) — gentle but fabric.",
     "listen": "Soft 'opens' or a bag?", "flags": ["WEAK", "NOISY"]},
    {"num": 102, "code": "DOUGH_REWARD", "file": "Ting Coins.wav", "section": "rewards",
     "roles": ["Hamur reward reveal (once per card)", "daily reward (0.95×)"], "family": None,
     "note": "1.1 s coin ting, 246 Hz body + 1.5 kHz ring, {pb} in the phone band; sharp onset is fine once per reveal.",
     "listen": "Currency without casino? One ting, never a cascade.", "flags": []},
    {"num": 103, "code": "LEGENDARY_REWARD", "file": "Cofetti Whoosh Pluck Spill.wav", "section": "rewards",
     "roles": ["Legendary reveal (trimmed to ~1.2 s)"], "family": None,
     "note": "2.5 s whoosh + plucks + spill, {pb} in the phone band, 16 % > 4 kHz — the one designed celebration that is confetti, not jackpot; 22 (music box) is the alternate.",
     "listen": "Premium celebration or slot-machine? Legendary is 3 % of chests, so 1.2 s is affordable.", "flags": ["TRIM", "LONG"]},

    # ---- 9. UI FAMILY (4) — all Kenney Interface Sounds ----
    {"num": 110, "code": "UI_TAP", "file": "select_002.ogg", "section": "ui",
     "roles": ["every button tap (−13 dB)", "dumpling release tick (event `drop`, −16 dB)"], "family": None,
     "note": "0.04 s tick 689→2326 Hz, {pb} in the phone band — a tick, not a click.",
     "listen": "Soft enough to hear 300 times per session?", "flags": []},
    {"num": 111, "code": "UI_CONFIRM", "file": "confirmation_001.ogg", "section": "ui",
     "roles": ["confirm / purchase / toggle on (1.2×) / select (0.85×)", "Hamur reward alternate"], "family": None,
     "note": "388→1174 Hz two-note up, 0.29 s, centroid 531 Hz, {pb} in the phone band, 244 ms decay.",
     "listen": "Warm 'yes' or slot-machine 'ding'?", "flags": []},
    {"num": 112, "code": "UI_BACK", "file": "back_002.ogg", "section": "ui",
     "roles": ["back / modal close (the tap's mirror, goes down)"], "family": None,
     "note": "0.07 s, 215→129 Hz descending, {pb} in the phone band (its 129 Hz end is felt, not heard, on a phone — the start carries it).",
     "listen": "Clearly 'back' at −12 dB, and related to 110?", "flags": []},
    {"num": 113, "code": "UI_ERROR", "file": "error_008.ogg", "section": "ui",
     "roles": ["disabled / insufficient Hamur (with the shake)"], "family": None,
     "note": "0.14 s muted low bonk, 108 Hz + mids (centroid 372 Hz), {pb} in the phone band — a polite 'no'; error_004 (descending blip) is the in-family alternate in the pool.",
     "listen": "Polite refusal or buzzer?", "flags": []},
]
# fmt: on

# Merge-family table order (M8.8-01.1 §4). A file may serve two labels; the
# optional third element overrides the one-sentence note for that label.
FAMILY_ROWS: list[tuple[str, int, str | None]] = [
    ("BODY A", 1, None), ("BODY B", 2, None), ("BODY C", 3, None),
    ("SPARKLE A", 10, None), ("SPARKLE B", 11, None),
    ("LARGE BODY A", 20, None), ("LARGE BODY B", 4, None),
    ("T8 BLOOM A", 21, None), ("T8 BLOOM B", 22, None),
    ("T8 TAIL A", 23, None),
    ("T8 TAIL B", 11, "Role: the warmer, organic tail alternative under the T8 bloom (the SPARKLE B file at 1.0×, +120 ms); survives repetition for the same reasons — two soft plucks, nothing past 0.36 s, and T8 is rare; survives a phone because {pb} of its energy sits in the 250 Hz-3 kHz speaker band."),
    ("CHIME T5-7 (between sparkle and bloom)", 13, None),
]

SECTIONS = [
    ("merge_body", "1. Merge body (BODY A / B / C + alternates)"),
    ("sparkle", "2. Sparkle / chime (SPARKLE A / B + alternates)"),
    ("large_t8", "3. Large body + Tier 8 bloom / tail"),
    ("drop", "4. Drop (landing)"),
    ("bomba", "5a. Bomba"),
    ("buyutucu", "5b. Büyütücü"),
    ("sarsinti", "5c. Sarsıntı — STILL WEAK"),
    ("temizleyici", "5d. Temizleyici"),
    ("danger", "6. Danger"),
    ("win_fail", "7. Win / fail"),
    ("rewards", "8. Chest / reward / skin — chest STILL WEAK"),
    ("ui", "9. UI family (Kenney Interface Sounds)"),
]


def safe_stem(name: str) -> str:
    stem = Path(name).stem
    return "".join(c if c.isalnum() or c in " -_.,()&'" else "_" for c in stem).strip()


def share_250_3k(path: Path) -> float:
    """Fraction of spectral power between 250 Hz and 3 kHz (phone band)."""
    data, sr = sf.read(str(path), dtype="float32", always_2d=True)
    mono = data.mean(axis=1)
    mono = mono[: int(min(len(mono), sr * 20))]
    nfft = 4096 if sr > 50000 else 2048
    hop = nfft // 2
    if len(mono) < nfft:
        mono = np.pad(mono, (0, nfft - len(mono)))
    n = min(1 + (len(mono) - nfft) // hop, 4000)
    win = np.hanning(nfft).astype(np.float32)
    freqs = np.fft.rfftfreq(nfft, 1.0 / sr)
    psum = np.zeros(len(freqs))
    for i in range(n):
        psum += np.abs(np.fft.rfft(mono[i * hop: i * hop + nfft] * win)) ** 2
    band = (freqs >= 250) & (freqs < 3000)
    return float(psum[band].sum() / (psum.sum() + 1e-12))



def pb(e: dict) -> str:
    """Measured share of energy in the 250 Hz-3 kHz phone band, for {pb} notes."""
    return f"{e['share_250_3k'] * 100:.0f} %"


def build_guide(entries: list[dict], out_dir_name: str) -> str:
    by_num = {e["num"]: e for e in entries}
    fam = [(label, by_num[num], note) for label, num, note in FAMILY_ROWS]
    L: list[str] = []
    L += ["# OWNER_LISTENING_GUIDE.md — M8.8-01.1 audio audition (43 files)", "",
          f"Branch `task/031-production-audio-audit`. Files: `{out_dir_name}/` — gain-matched to "
          f"{TARGET_RMS_DBFS:.0f} dBFS RMS (peak ceiling {PEAK_CEILING_DBFS:.0f} dBFS), silence trimmed, "
          "2/15 ms fades, **no compression, no EQ, no edits** — you are hearing the source character. "
          "Long files (music box, wobble, swoosh, confetti) are left whole; the note says which part matters.", "",
          "Nothing is in the game yet. Your answers decide what gets integrated in M8.8-02.", "",
          "## Judge ONLY these four things", "",
          "1. **Does it feel soft?** (yumuşak mı?)",
          "2. **Would hearing it 100 times annoy you?** (100 kez duysan bıkar mısın?)",
          "3. **Does it fit a cute dumpling?** (sevimli bir dumpling'e yakışıyor mu?)",
          "4. **Does it sound premium or cheap?** (premium mi, ucuz mu?)", "",
          "Ignore loudness (already matched), stereo width, length of the long files, and any hiss you only "
          "hear on headphones — production copies will be mono, trimmed and low-passed. If possible listen once "
          "on headphones and once on the phone speaker; the `phone band` column is the share of the sound's "
          "energy between 250 Hz and 3 kHz (what a phone speaker can actually reproduce).", "",
          "## Listening order", "",
          "1. Merge body A/B/C (01–05) · 2. Sparkle A/B (10–13) · 3. Large body A/B (20, 04) · 4. T8 bloom/tail (21–23, 11) · "
          "5. Drop (30–32) · 6. Powers (40–72) · 7. Rewards (90–103) · 8. UI (110–113)", "",
          "Mark each file **KEEP / MAYBE / NO** (a scoring sheet is at the end). For the merge family pick "
          "**one** BODY, **one** SPARKLE, **one** LARGE BODY, **one** BLOOM and **one** TAIL — alternates only "
          "matter if the primary fails.", "",
          "## Merge family (most important)", "",
          "| label | file | role · why it survives repetition · why it survives a phone speaker |", "|---|---|---|"]
    for label, e, note in fam:
        L.append(f"| **{label}** | `{e['fname']}` | {(note or e['note']).format(pb=pb(e))} |")
    L += ["", "Shared roles: **LARGE BODY B** = 04 (also merge body D) · **T8 TAIL B** = 11 (also SPARKLE B) · "
          "the glass tick 10 stepped ×3 is the no-new-file fallback tail. The chime 13 is the tier 5–7 bell "
          "between sparkle and bloom. Per-tier pitch/gain/offset recipe: `MERGE_SOUND_FAMILY_BLUEPRINT.md` §2.", "",
          "## Why these and not the other 120", "",
          "Metrics only rejected obvious problems: sub-only sounds a phone cannot reproduce (the shipped "
          "`kenney_impact_soft_01`, Kenney impactSoft/impactMining/plate_heavy, Sonniss bass drops), sounds "
          "dominated by energy above 4 kHz (Kenney glass_004, close_/open_ hiss, the scratch-card wipe which "
          "also clips), 10 ms glitch clicks, a clipping buzzer, chiptune / orchestral hits / lounge sax, and "
          "the four malformed SoundBits WAVs. Everywhere taste decides — bubble vs. dry dough, glass vs. "
          "kalimba, bell vs. music box, pizzicato vs. steel drum, latch vs. cloth — both options are here. "
          "Kenney Music Jingles are limited to win/fail; nothing musical touches tiers 1–6.", ""]
    for key, title in SECTIONS:
        L += [f"## {title}", "", "| # | file | role(s) | what it is · listen for | phone band | length | flags |", "|---|---|---|---|---|---|---|"]
        for e in entries:
            if e["section"] != key:
                continue
            roles = "; ".join(e["roles"])
            L.append(f"| {e['num']:03d} | `{e['fname']}` | {roles} | {e['note'].format(pb=pb(e))} {e['listen']} | {e['share_250_3k'] * 100:.0f} % | "
                     f"{e['duration_s']:.2f} s | {' '.join(e['flags'])} |")
        if key == "sarsinti":
            L += ["", "**Verdict: STILL WEAK — SOURCE ANOTHER SOUND.** Two of three candidates keep ≤ 15 % of their "
                  "energy in the phone band and the third is a 3.5 s cartoon transition that needs a hard trim. "
                  "Nothing in the downloaded packs is a short, soft, phone-readable jelly wobble. Keep 60/62 only "
                  "if the trimmed start genuinely convinces you; otherwise one targeted sound (0.3–0.5 s wobble "
                  "with 200–600 Hz body) is sourced later."]
        if key == "rewards":
            L += ["", "**Chest open: STILL WEAK — SOURCE ANOTHER SOUND (probably).** A mechanical latch (100) and a "
                  "cloth lid (101) are the only 'open' sounds in the library; neither is candy/kawaii. Dough (102), "
                  "Legendary (103), skin unlock (23) and Rare/Epic (52/53) are adequate for v1."]
        L.append("")
    L += ["## Adequacy summary", "",
          "| category | status |", "|---|---|",
          "| Merge family (body / sparkle / large / T8) | ADEQUATE FOR V1 — real choices available |",
          "| Drop | ADEQUATE FOR V1 (cloth/carpet stand-ins; no true dough recording exists in the packs) |",
          "| Bomba, Büyütücü, Temizleyici | ADEQUATE FOR V1 |",
          "| Sarsıntı | **STILL WEAK — SOURCE ANOTHER SOUND** |",
          "| Danger | ADEQUATE FOR V1 |",
          "| Win / fail | ADEQUATE FOR V1 (pizzicato / steel; 53 as non-jingle win) |",
          "| Chest open | **STILL WEAK — SOURCE ANOTHER SOUND** |",
          "| Dough / Legendary / skin unlock | ADEQUATE FOR V1 |",
          "| UI family | ADEQUATE FOR V1 — one family (Kenney Interface), modal open/close pair `maximize_008`/`minimize_008` available in the same family |",
          "| Music | none in the packs — deferred (v1 non-goal) |", "",
          "## Scoring sheet", "", "| # | file | KEEP / MAYBE / NO | note |", "|---|---|---|---|"]
    for e in entries:
        L.append(f"| {e['num']:03d} | `{e['fname']}` |  |  |")
    L += ["", "Send this file back (or just the numbers + KEEP/MAYBE/NO) — M8.8-02 integrates only KEEPs.", ""]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=SOURCE_DEFAULT)
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--zip", action="store_true")
    args = ap.parse_args()
    source = Path(args.source)
    out = Path(args.out)
    inv_path = out / "AUDIO_SOURCE_INVENTORY.json"
    if not inv_path.exists():
        print(f"missing {inv_path} — run tools/audio_source_audit.py first", file=sys.stderr)
        return 2
    by_name: dict[str, list[dict]] = {}
    for r in json.load(open(inv_path, encoding="utf-8")):
        by_name.setdefault(r["filename"], []).append(r)

    nums = [e["num"] for e in OWNER_SHORTLIST]
    files = [e["file"] for e in OWNER_SHORTLIST]
    assert len(nums) == len(set(nums)), "duplicate numbers"
    assert len(files) == len(set(files)), "a file may appear only once (cross-reference shared roles instead)"

    out_dir = out / "owner_shortlist"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    entries: list[dict] = []
    for e in sorted(OWNER_SHORTLIST, key=lambda x: x["num"]):
        rows = by_name.get(e["file"])
        if not rows or len(rows) != 1:
            print(f"cannot resolve {e['file']!r} ({0 if not rows else len(rows)} matches)", file=sys.stderr)
            return 1
        r = rows[0]
        src = source / r["rel_path"]
        fname = f"{e['num']:03d}_{e['code']}__{safe_stem(r['filename'])}.wav"
        norm = normalise(src, out_dir / fname)
        rec = {**e, "fname": fname, "row": r, "share_250_3k": share_250_3k(src),
               "duration_s": float(r["duration_s"]), **norm}
        entries.append(rec)

    index_fields = ["num", "code", "audition_file", "source_filename", "source_pack", "source_library",
                    "source_supplier", "source_url", "source_rel_path", "license", "roles", "merge_family",
                    "flags", "duration_s", "samplerate", "channels", "bit_depth", "peak_dbfs", "rms_active_dbfs",
                    "spectral_centroid_hz", "share_250_3k", "share_low_200hz", "share_high_4k_plus",
                    "transient_db_per_10ms", "effective_len_s", "audition_gain_db", "audition_len_s"]
    with open(out_dir / "owner_shortlist_index.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=index_fields)
        w.writeheader()
        for e in entries:
            r = e["row"]
            w.writerow({
                "num": e["num"], "code": e["code"], "audition_file": e["fname"], "source_filename": r["filename"],
                "source_pack": r["pack"], "source_library": r.get("library", ""), "source_supplier": r.get("supplier", ""),
                "source_url": r.get("library_url", ""), "source_rel_path": r["rel_path"], "license": r["license"],
                "roles": "; ".join(e["roles"]), "merge_family": e.get("family") or "", "flags": " ".join(e["flags"]),
                "duration_s": r["duration_s"], "samplerate": r["samplerate"], "channels": r["channels"],
                "bit_depth": r["bit_depth"], "peak_dbfs": r["peak_dbfs"], "rms_active_dbfs": r["rms_active_dbfs"],
                "spectral_centroid_hz": r["spectral_centroid_hz"], "share_250_3k": round(e["share_250_3k"], 4),
                "share_low_200hz": r["share_low_200hz"], "share_high_4k_plus": r["share_high_4k_plus"],
                "transient_db_per_10ms": r["transient_db_per_10ms"], "effective_len_s": r["effective_len_s"],
                "audition_gain_db": e.get("audition_gain_db"), "audition_len_s": e.get("audition_len_s"),
            })

    guide = build_guide(entries, out_dir.name)
    (out / "OWNER_LISTENING_GUIDE.md").write_text(guide, encoding="utf-8")

    per_section = {k: sum(1 for e in entries if e["section"] == k) for k, _ in SECTIONS}
    total_bytes = sum((out_dir / e["fname"]).stat().st_size for e in entries)
    print(f"owner shortlist: {len(entries)} files, {total_bytes / 1e6:.1f} MB -> {out_dir}")
    for k, t in SECTIONS:
        print(f"  {k:12} {per_section[k]}")

    if args.zip:
        zpath = out / "M8.8-01_OWNER_AUDIO_SHORTLIST.zip"
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for d in BUNDLE_DOCS:
                p = out / d
                if not p.exists():
                    print(f"  (bundle) missing doc: {d}", file=sys.stderr)
                    return 1
                z.write(p, d)
            for e in entries:
                z.write(out_dir / e["fname"], f"{out_dir.name}/{e['fname']}")
            z.write(out_dir / "owner_shortlist_index.csv", f"{out_dir.name}/owner_shortlist_index.csv")
        print(f"bundle: {zpath} ({zpath.stat().st_size / 1e6:.1f} MB, {len(entries)} audio + {len(BUNDLE_DOCS)} docs + index)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
