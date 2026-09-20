#!/usr/bin/env python
"""audio_audition_export.py — M8.8-01 shortlist → owner listening folders.

Reads the inventory written by ``tools/audio_source_audit.py`` and the
SHORTLIST below (the audit's actual selection, one entry per candidate per
category), then writes — OUTSIDE the production asset tree —

    build/qa_m8.8-01/auditions/<category>/NN_<original filename>
        byte-identical copies of the shortlisted originals, numbered in the
        recommended listening order; index.csv per folder keeps pack /
        relative source path / verdict / reason / flags.
    build/qa_m8.8-01/auditions_normalized/<category>/NN_<stem>.wav
        OWNER-LISTENING-ONLY copies: leading/trailing silence trimmed, 2 ms
        fade-in / 15 ms fade-out, gain matched to a common RMS so "louder"
        does not read as "better". 16-bit PCM at the ORIGINAL sample rate
        and channel count (no resampling, no EQ, no compression). Not
        production processing; originals are never touched.
    build/qa_m8.8-01/LISTENING_ORDER.md   listening order + verdicts
    build/qa_m8.8-01/SHORTLIST.json        machine-readable selection
    build/qa_m8.8-01/M8.8-01_audio_review_bundle.zip  (with --zip)

Verdicts: STRONG = strong candidate, ALT = alternate, REF = included only
as a reference (current in-game sample or an instructive reject). Every
entry carries the exact reason; numbers are filters, the owner's ear is
the decision.

Requires the same isolated venv as the audit (numpy + soundfile).
Nothing here touches the Godot project, assets/ or the runtime.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
import sys
import zipfile
from pathlib import Path

import numpy as np
import soundfile as sf

SOURCE_DEFAULT = r"D:\dev\squishy-audio-source"
OUT_DEFAULT = "build/qa_m8.8-01"

# Listening normalisation targets (audition only).
TARGET_RMS_DBFS = -20.0
PEAK_CEILING_DBFS = -1.0
TRIM_LEAD_DB = -50.0
TRIM_TAIL_DB = -60.0
LEAD_PREROLL_S = 0.005
TAIL_KEEP_S = 0.08
FADE_IN_S = 0.002
FADE_OUT_S = 0.015

# Flags: PHONE = relies on sub-bass / width that phone speakers drop,
# FATIGUE = transient/tail likely tiring on 100s of repeats, TRIM = needs a
# trim to be usable, BRIGHT = high-frequency share may pierce, LONG = too
# long as-is, NOISY = noise-based (whoosh/shimmer) rather than tonal.

# fmt: off
SHORTLIST: list[dict] = [
    # ---------------- A. DROP / first impact  (target 5-8) ----------------
    {"cat": "drop", "file": "footstep_carpet_000.ogg", "verdict": "STRONG",
     "role": "landing 'puf' core", "reason": "0.14 s, centroid 445 Hz, gentle 12 dB/10 ms onset, 52 % energy < 200 Hz but body reaches 300-800 Hz: soft cloth puf, no rubber, no wetness."},
    {"cat": "drop", "file": "footstep_carpet_003.ogg", "verdict": "STRONG",
     "role": "landing variant (lighter)", "reason": "same family, effective 0.07 s, centroid 304 Hz: the tier-1/2 landing, also a natural pitch-up variant."},
    {"cat": "drop", "file": "FOLYClth_SinglePats04_InMotionAudio_FoleyT-Shirt.wav", "verdict": "STRONG",
     "role": "dough 'plop' (fuller)", "reason": "cloth pat, centroid 388 Hz, 64 % < 200 Hz with mid body; 0.57 s tail should be trimmed to ~0.20 s.", "flags": ["TRIM"]},
    {"cat": "drop", "file": "impactGeneric_light_001.ogg", "verdict": "ALT",
     "role": "rounded light tap", "reason": "0.12 s, centroid 581 Hz, near-zero transient slope (1 dB/10 ms): very rounded; may read as generic 'tap' rather than dough."},
    {"cat": "drop", "file": "footstep_snow_000.ogg", "verdict": "ALT",
     "role": "puf with texture", "reason": "0.37 s, centroid 504 Hz, decay 95 ms; adds a little crunch — listen for 'too crunchy'."},
    {"cat": "drop", "file": "CLOTHFlp_Action Inventory Open Flip Cloth Canvas Bag Slide Light 02_ESM_FG2.wav", "verdict": "ALT",
     "role": "soft cloth flip", "reason": "0.69 s, centroid 1.4 kHz, flatness 0.27 (noisier): airier plop, would need trim; risk of reading as fabric.", "flags": ["TRIM", "NOISY"]},
    {"cat": "drop", "file": "drop_002.ogg", "verdict": "ALT",
     "role": "designed UI drop", "reason": "Kenney Interface 'drop': 0.19 s (eff 0.09), tonal 791 Hz; clean but may sound like a UI blip, not a body."},
    {"cat": "drop", "file": "impactWood_light_001.ogg", "verdict": "ALT",
     "role": "very short 'tok'", "reason": "eff 0.10 s, centroid 315 Hz, transient 6 dB/10 ms; risk: wooden knock instead of dough."},
    {"cat": "drop", "file": "select_002.ogg", "verdict": "ALT",
     "role": "release tick (the throw, event `drop`)", "reason": "0.04 s tick 689→2326 Hz, −16 dBFS RMS: the barely-there 'let go' sound; must sit at −14 dB or lower."},
    {"cat": "drop", "file": "impactSoft_medium_000.ogg", "verdict": "REF",
     "role": "CURRENT land / merge_body sample", "reason": "centroid 97 Hz, 100 % of energy < 200 Hz: a sub thud — effectively inaudible on a phone speaker. This is why the current landing feels silent on device.", "flags": ["PHONE"]},

    # ---------------- B. MERGE SOFT BODY  (target 10-15) ----------------
    {"cat": "merge_body", "file": "Cartoon Bubbles Short.wav", "verdict": "STRONG",
     "role": "bubble 'blup' core (T1-T4 with pitch)", "reason": "tonal (flatness 0.000) 281→393 Hz rising blup, centroid 390 Hz, 0.88 s — trim to ~0.30 s. Closest thing in the library to 'gentle bubble/pop'. Listen for cartoon exaggeration.", "flags": ["TRIM"]},
    {"cat": "merge_body", "file": "impactGeneric_light_002.ogg", "verdict": "STRONG",
     "role": "soft rounded body", "reason": "0.14 s, centroid 614 Hz, 21 % < 200 Hz, transient ~0 dB/10 ms: round, no click, survives repetition."},
    {"cat": "merge_body", "file": "impactGeneric_light_004.ogg", "verdict": "STRONG",
     "role": "body variant", "reason": "0.14 s, centroid 712 Hz, 32 % < 200 Hz — pairs with _002 as a 2-variant pool."},
    {"cat": "merge_body", "file": "impactPlate_light_000.ogg", "verdict": "STRONG",
     "role": "warm dull body (T3-T4)", "reason": "eff 0.42 s, centroid 604 Hz, 66 % < 200 Hz, decay 50 ms: fuller and warmer than generic_light, still soft."},
    {"cat": "merge_body", "file": "impactPlate_medium_000.ogg", "verdict": "STRONG",
     "role": "fuller body (T4-T5)", "reason": "eff 0.50 s, centroid 358 Hz, 69 % < 200 Hz, decay 60 ms: the 'fuller' step without going sub-only."},
    {"cat": "merge_body", "file": "impactPlate_light_003.ogg", "verdict": "ALT",
     "role": "body variant", "reason": "centroid 812 Hz, 45 % < 200 Hz: brighter sibling of plate_light_000."},
    {"cat": "merge_body", "file": "impactPlate_medium_002.ogg", "verdict": "ALT",
     "role": "body variant", "reason": "centroid 417 Hz, 74 % < 200 Hz, decay 70 ms."},
    {"cat": "merge_body", "file": "footstep_carpet_001.ogg", "verdict": "ALT",
     "role": "puf body (shares drop family)", "reason": "centroid 454 Hz, decay 50 ms: using the drop family for merge keeps one material; risk: merge and landing blur together."},
    {"cat": "merge_body", "file": "bong_001.ogg", "verdict": "ALT",
     "role": "low 'wumm' pop under body", "reason": "0.12 s pure ~237 Hz (flatness 0.000): a soft low pop that can sit under the body layer for T3+; phone-safe (above 200 Hz)."},
    {"cat": "merge_body", "file": "drop_003.ogg", "verdict": "ALT",
     "role": "tonal pop", "reason": "0.19 s (eff 0.09), tonal 727 Hz; clean UI-style pop — may be too 'digital'."},
    {"cat": "merge_body", "file": "impactWood_medium_002.ogg", "verdict": "ALT",
     "role": "'tok' body", "reason": "eff 0.17 s, centroid 252 Hz, decay 25 ms: compact; risk: reads as wood."},
    {"cat": "merge_body", "file": "Interface Pop High Short.wav", "verdict": "ALT",
     "role": "tiny pop (T1 only)", "reason": "tonal 1.6→2.1 kHz pop, but 172 dB/10 ms transient — sharp; keep only as a T1 accent at low gain.", "flags": ["FATIGUE"]},
    {"cat": "merge_body", "file": "error_007.ogg", "verdict": "ALT",
     "role": "soft 764 Hz thud", "reason": "0.19 s, centroid 567 Hz, 61 % < 200 Hz; the name is Kenney's, the sound is a soft muted pop."},
    {"cat": "merge_body", "file": "impactSoft_medium_000.ogg", "verdict": "REF",
     "role": "CURRENT merge_body layer", "reason": "sub-only (centroid 97 Hz): on phone the current 'body' layer vanishes, leaving only the synth pop.", "flags": ["PHONE"]},

    # ---------------- C. SPARKLE / CHIME  (target 8-12) + F. combo ----------------
    {"cat": "sparkle", "file": "impactGlass_light_002.ogg", "verdict": "STRONG",
     "role": "tiny glass core (pitch-steppable)", "reason": "pure tonal ~1.1 kHz (flatness 0.001), 0.21 s (eff 0.12), decay 50 ms, 0 % > 4 kHz: tiny glass without piercing highs."},
    {"cat": "sparkle", "file": "impactGlass_light_004.ogg", "verdict": "STRONG",
     "role": "tiny glass variant", "reason": "926 Hz sibling; 2-3 of these at ±5 % pitch make a non-repetitive sparkle pool."},
    {"cat": "sparkle", "file": "impactGlass_light_000.ogg", "verdict": "STRONG",
     "role": "tiny glass variant", "reason": "1077 Hz sibling."},
    {"cat": "sparkle", "file": "glass_001.ogg", "verdict": "STRONG",
     "role": "soft glass ting (T3-T5 sparkle)", "reason": "Kenney Interface glass: ~1.9 kHz tonal, 0.28 s, decay 90 ms, 0 % > 4 kHz: gentle, longer shimmer."},
    {"cat": "sparkle", "file": "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav", "verdict": "STRONG",
     "role": "warm chime / combo sweetener", "reason": "kalimba, 703→1055 Hz (+7 st) rising, 0.55 s, centroid 2.7 kHz: warm and organic, exactly the 'warm cute' brief; 23 % > 4 kHz — check on phone."},
    {"cat": "sparkle", "file": "impactGlass_medium_001.ogg", "verdict": "ALT",
     "role": "glass with body", "reason": "1.0 kHz tonal, 0.54 s (eff 0.28): a heavier glass for T5-T7."},
    {"cat": "sparkle", "file": "impactGlass_medium_003.ogg", "verdict": "ALT",
     "role": "glass with body variant", "reason": "958 Hz, decay 70 ms."},
    {"cat": "sparkle", "file": "glass_003.ogg", "verdict": "ALT",
     "role": "0.12 s glass tick", "reason": "1.9→2.1 kHz, very short: for chain merges where the long ting would smear."},
    {"cat": "sparkle", "file": "glass_006.ogg", "verdict": "ALT",
     "role": "0.11 s glass tick", "reason": "1.4 kHz, softer than glass_003."},
    {"cat": "sparkle", "file": "pluck_002.ogg", "verdict": "ALT",
     "role": "pluck (current star family)", "reason": "2.0 kHz pluck 0.16 s; pluck_001 (currently shipped) clips at +0.43 dBFS — this sibling peaks at −0.46."},
    {"cat": "sparkle", "file": "Interface Accept Glassy Snap.wav", "verdict": "ALT",
     "role": "glassy accept", "reason": "926 Hz glassy, 0.44 s, quiet (−9 dBFS peak): usable but more 'UI' than 'magic'."},
    {"cat": "sparkle", "file": "toggle_001.ogg", "verdict": "ALT",
     "role": "tonal tick", "reason": "1.4→1.9 kHz, 0.14 s, 13 % > 4 kHz."},
    {"cat": "sparkle", "file": "Interface Plucks Happy.wav", "verdict": "ALT",
     "role": "combo sweetener (F)", "reason": "967→1283 Hz plucks, 0.85 s, tonal: combo x3+ layer candidate; too long for every merge."},
    {"cat": "sparkle", "file": "glass_004.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "7.3 kHz, 100 % of energy > 4 kHz: exactly the piercing high the brief forbids.", "flags": ["BRIGHT"]},

    # ---------------- D. LARGE MERGE BODY (T5-T7) ----------------
    {"cat": "large_merge", "file": "impactPunch_medium_001.ogg", "verdict": "STRONG",
     "role": "warm mid thump", "reason": "0.40 s, centroid 198 Hz, 47 % < 200 Hz (half the energy is mids → phone-safe), transient 30 dB/10 ms compact: 'warm body impact' without aggression."},
    {"cat": "large_merge", "file": "impactPlate_medium_003.ogg", "verdict": "STRONG",
     "role": "deep body", "reason": "eff 0.57 s, centroid 177 Hz, 85 % < 200 Hz, decay 125 ms: the deepest body that still has some mids.", "flags": ["PHONE"]},
    {"cat": "large_merge", "file": "impactBell_heavy_002.ogg", "verdict": "STRONG",
     "role": "soft bell chime for T5+", "reason": "226 Hz bell, 0.70 s (eff 0.44), decay 95 ms, pure tonal: the 'lower warm body + chime' step of the brief."},
    {"cat": "large_merge", "file": "impactBell_heavy_004.ogg", "verdict": "ALT",
     "role": "muted short bell", "reason": "344 Hz, 0.30 s, 41 % < 200 Hz: a shorter chime for T5."},
    {"cat": "large_merge", "file": "impactBell_heavy_003.ogg", "verdict": "ALT",
     "role": "bell variant", "reason": "323 Hz, 0.65 s, decay 115 ms."},
    {"cat": "large_merge", "file": "impactPunch_medium_003.ogg", "verdict": "ALT",
     "role": "thump variant", "reason": "centroid 202 Hz, 39 % < 200 Hz."},
    {"cat": "large_merge", "file": "impactPlate_heavy_000.ogg", "verdict": "ALT",
     "role": "heavier plate", "reason": "centroid 227 Hz, 83 % < 200 Hz, decay 90 ms.", "flags": ["PHONE"]},
    {"cat": "large_merge", "file": "WATRMisc_Water, Liquid Impact, Bubble, Sci Fi, Hit 04_344 Audio_Elemental Palette Designed Vol 1.wav", "verdict": "ALT",
     "role": "liquid body", "reason": "1.21 s, centroid 308 Hz, 81 % < 200 Hz: big soft liquid hit; risk: 'wet' and 'sci-fi' — both on the avoid list, listen before dismissing.", "flags": ["PHONE", "TRIM"]},
    {"cat": "large_merge", "file": "impactSoft_heavy_001.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "centroid 89 Hz, 100 % < 200 Hz: pure sub — gone on phone.", "flags": ["PHONE"]},

    # ---------------- E. TIER 8 bloom ----------------
    {"cat": "tier8", "file": "impactBell_heavy_000.ogg", "verdict": "STRONG",
     "role": "warm bell bloom (body of T8)", "reason": "380 Hz bell, 1.48 s (eff 1.05), decay 249 ms, pure tonal, 0 % > 4 kHz: warm bloom that is clearly 'bigger' than the T5 chime."},
    {"cat": "tier8", "file": "SBmb_Music Box A 013.wav", "verdict": "STRONG",
     "role": "soft bell/chime layer", "reason": "music box ~945 Hz, 2.84 s, tonal (flatness 0.003), 1 % > 4 kHz: cute-premium chime; trim to the first note(s).", "flags": ["TRIM", "LONG"]},
    {"cat": "tier8", "file": "Button Arp Twinkle.wav", "verdict": "STRONG",
     "role": "short sparkle tail", "reason": "rising arp 2.7→4.1 kHz, 1.81 s, tonal; 48 % > 4 kHz so it must be low in the mix and trimmed to ~0.6 s.", "flags": ["BRIGHT", "TRIM"]},
    {"cat": "tier8", "file": "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav", "verdict": "STRONG",
     "role": "chime alternative (warmer than music box)", "reason": "see sparkle; at T8 it can play at 1.0× under the bell."},
    {"cat": "tier8", "file": "SBmb_Music Box C 059.wav", "verdict": "ALT",
     "role": "descending music-box phrase", "reason": "1570→621 Hz phrase, 2.72 s: prettier but melodic — a melody on every T8 gets recognisable fast.", "flags": ["TRIM", "LONG", "FATIGUE"]},
    {"cat": "tier8", "file": "DSGNStngr_Power Up Bright Positive Successful Light Saturation Crash Shimmer 05_ESM_AG.wav", "verdict": "ALT",
     "role": "bright shimmer", "reason": "1.52 s, flatness 0.52 (noise-based), 37 % > 4 kHz, 'crash': probably harsher than the brief; included because it is the only designed 'power up shimmer' in the library.", "flags": ["BRIGHT", "NOISY"]},
    {"cat": "tier8", "file": "Game Entry Happy Short.wav", "verdict": "ALT",
     "role": "short 'ta-da'", "reason": "445→1043 Hz rising, 0.88 s, tonal, centroid 829 Hz: warm two-note; a candidate if T8 should be melodic rather than bloom."},
    {"cat": "tier8", "file": "jingles_STEEL09.ogg", "verdict": "ALT",
     "role": "steel-drum riser", "reason": "334→592 Hz (+10 st), 0.59 s: warm and short; risk: reads as 'win' instead of 'merge'."},
    {"cat": "tier8", "file": "confirmation_002.ogg", "verdict": "ALT",
     "role": "rising two-note", "reason": "1174→3521 Hz (+19 st), 0.54 s: brighter riser; 5 % > 4 kHz."},
    {"cat": "tier8", "file": "TOONMisc_Bird Flutes 3_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "cute flute accent", "reason": "2.4 kHz flute, 1.03 s, tonal: cute but a novelty — could wear out on repeated T8s.", "flags": ["FATIGUE"]},

    # ---------------- G. BOMBA ----------------
    {"cat": "bomb", "file": "minimize_006.ogg", "verdict": "STRONG",
     "role": "launch: falling tone", "reason": "603→269 Hz descending (−14 st), 0.38 s, pure tonal: a 'falling' cue that matches the 0.28 s travel; distinct from the noisy sweeps used elsewhere."},
    {"cat": "bomb", "file": "Woosh Sweep Slide Infographics Basic.wav", "verdict": "ALT",
     "role": "launch: airy whoosh", "reason": "562→1629 Hz rising sweep, 0.50 s, flatness 0.12: light airy whoosh; if used here, give Temizleyici a different sweep.", "flags": ["NOISY"]},
    {"cat": "bomb", "file": "impactPunch_medium_000.ogg", "verdict": "STRONG",
     "role": "impact: compact 'pop-bum'", "reason": "0.43 s, centroid 182 Hz, 49 % < 200 Hz, transient 23 dB/10 ms: compact body hit with mids — phone-readable, not an explosion."},
    {"cat": "bomb", "file": "footstep_snow_000.ogg", "verdict": "ALT",
     "role": "impact: soft poof layer", "reason": "0.37 s puf with texture, centroid 504 Hz: the 'soft poof' to layer on top of the thump."},
    {"cat": "bomb", "file": "impactPlank_medium_001.ogg", "verdict": "ALT",
     "role": "impact: woody thud", "reason": "eff 0.38 s, centroid 140 Hz, 87 % < 200 Hz.", "flags": ["PHONE"]},
    {"cat": "bomb", "file": "error_006.ogg", "verdict": "ALT",
     "role": "impact: soft 162 Hz thud", "reason": "0.50 s (eff 0.21), 85 % < 200 Hz: rounder than punch, but mostly low.", "flags": ["PHONE"]},
    {"cat": "bomb", "file": "EXPLDsgn_Explosion Small Blast Enemy Death Crunchy Boom Cartoon Noisy Crash Impact Delay 03_ESM_AG.wav", "verdict": "ALT",
     "role": "impact: cartoon boom", "reason": "1.48 s, transient 163 dB/10 ms, centroid 801 Hz, 64 % < 200 Hz: a real cartoon explosion — likely too aggressive for the brief, kept so the owner can hear the ceiling.", "flags": ["FATIGUE", "TRIM"]},
    {"cat": "bomb", "file": "WINDDsgn_Wind, Rush, Whoosh, Long x5 01_344 Audio_Elemental Palette Designed Vol 1.wav", "verdict": "ALT",
     "role": "launch: airy wind whoosh (needs slicing)", "reason": "five whooshes in one 1.05 s file, quiet (−15 dBFS peak), flatness 0.61: airy; one slice could be the bomb flight.", "flags": ["TRIM", "NOISY"]},

    # ---------------- H/I. BÜYÜTÜCÜ charge + transform ----------------
    {"cat": "upgrade", "file": "maximize_006.ogg", "verdict": "STRONG",
     "role": "charge: rising tone (0.15 s anticipation)", "reason": "269→603 Hz rising (+14 st), 0.38 s, tonal: reads as 'loading up'; plays at the tap, before the transform."},
    {"cat": "upgrade", "file": "Woosh Sweep Slide Infographics Basic.wav", "verdict": "STRONG",
     "role": "charge: airy rising whoosh", "reason": "562→1629 Hz rising sweep, 0.50 s: the 'airy rising whoosh' of the brief; pairs under maximize_006.", "flags": ["NOISY"]},
    {"cat": "upgrade", "file": "maximize_009.ogg", "verdict": "ALT",
     "role": "charge: brighter riser", "reason": "1120→1680 Hz, 0.22 s."},
    {"cat": "upgrade", "file": "maximize_008.ogg", "verdict": "ALT",
     "role": "charge: shorter riser", "reason": "269→409 Hz, 0.23 s."},
    {"cat": "upgrade", "file": "Cartoon Pull Swoosh Readout.wav", "verdict": "ALT",
     "role": "charge: long cartoon swoosh", "reason": "2.29 s, +11 st: too long as-is; the first 0.4 s could work.", "flags": ["TRIM", "LONG"]},
    {"cat": "upgrade", "file": "Interface Plucks Happy.wav", "verdict": "STRONG",
     "role": "transform: magical plucks", "reason": "967→1283 Hz plucks, 0.85 s, tonal, centroid 1.6 kHz: 'magical shimmer' that is warm rather than glassy."},
    {"cat": "upgrade", "file": "Game Entry Happy Short.wav", "verdict": "STRONG",
     "role": "transform: warm two-note", "reason": "445→1043 Hz, 0.88 s: friendly 'became bigger' cue; transform then hands over to the merge sound of the new tier."},
    {"cat": "upgrade", "file": "GAMEMisc_Magic Creation 23_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "transform: magic texture", "reason": "3.19 s, flatness 0.35, 24 % > 4 kHz: rich magical bloom; needs a 0.6 s trim and low gain.", "flags": ["TRIM", "LONG", "NOISY"]},
    {"cat": "upgrade", "file": "DSGNStngr_Power Up Bright Positive Successful Light Saturation Crash Shimmer 05_ESM_AG.wav", "verdict": "ALT",
     "role": "transform: bright shimmer", "reason": "see tier8 — probably harsh.", "flags": ["BRIGHT", "NOISY"]},
    {"cat": "upgrade", "file": "MAGAngl_Magic Light Spell Enchantment Potion Effect Tonal Bright 03_ESM_FG2.wav", "verdict": "ALT",
     "role": "transform: tonal spell", "reason": "5.20 s, centroid 1.4 kHz, 51 % < 200 Hz: tonal magic with body; far too long — first 0.7 s only.", "flags": ["TRIM", "LONG"]},
    {"cat": "upgrade", "file": "confirmation_002.ogg", "verdict": "ALT",
     "role": "transform: rising two-note", "reason": "+19 st, 0.54 s: simplest option."},
    {"cat": "upgrade", "file": "Button Arp Twinkle.wav", "verdict": "ALT",
     "role": "transform: sparkle tail", "reason": "see tier8; risk of Büyütücü and T8 sounding the same.", "flags": ["BRIGHT", "TRIM"]},

    # ---------------- J. SARSINTI low pulse ----------------
    {"cat": "shake", "file": "Vibrato Impact Snap Spin Transition.wav", "verdict": "STRONG",
     "role": "jelly wobble", "reason": "centroid 281 Hz, 85 % < 200 Hz but a vibrato/wobble character (name + f0 ~1.05 kHz modulation), 3.2 s → trim to the first 0.45 s: the one 'wobble' in the library.", "flags": ["TRIM", "LONG", "PHONE"]},
    {"cat": "shake", "file": "impactPlate_medium_003.ogg", "verdict": "STRONG",
     "role": "short low warm pulse", "reason": "centroid 177 Hz, decay 125 ms, eff 0.57 s: the 'wumm' with some mids; if also used for T6-T7 body, pitch it 0.8× here for identity.", "flags": ["PHONE"]},
    {"cat": "shake", "file": "switch_003.ogg", "verdict": "ALT",
     "role": "low thud", "reason": "0.50 s (eff 0.21), 140 Hz, 94 % < 200 Hz.", "flags": ["PHONE"]},
    {"cat": "shake", "file": "impactPunch_heavy_000.ogg", "verdict": "ALT",
     "role": "heavier pulse", "reason": "centroid 122 Hz, decay 165 ms, transient 41 dB/10 ms: warmer but starts to feel like a hit.", "flags": ["PHONE"]},
    {"cat": "shake", "file": "Cartoon Transition Bass Down.wav", "verdict": "ALT",
     "role": "descending wobble", "reason": "568→190 Hz (−19 st), 3.5 s, centroid 454 Hz: the top 0.5 s is a soft down-wobble.", "flags": ["TRIM", "LONG"]},
    {"cat": "shake", "file": "error_006.ogg", "verdict": "ALT",
     "role": "soft 162 Hz bonk", "reason": "0.50 s; rounder than switch_003.", "flags": ["PHONE"]},
    {"cat": "shake", "file": "DSGNBass_Jump Start Drop 3_344 Audio_Bass Drops and Downers Vol 3.wav", "verdict": "ALT",
     "role": "designed drop (sub-heavy)", "reason": "3.7 s, centroid 257 Hz, 55 % < 200 Hz, 192 kHz: cinematic; mostly sub on phone.", "flags": ["PHONE", "TRIM", "LONG"]},
    {"cat": "shake", "file": "DSGNBass_Bass Drop & Downer Fast 16_344 Audio_Bass Drops & Downers.wav", "verdict": "REF",
     "role": "REJECT reference", "reason": "centroid 37 Hz, 98 % < 200 Hz: pure sub drop — silence on a phone speaker.", "flags": ["PHONE"]},

    # ---------------- K/L. TEMİZLEYİCİ sweep + pops ----------------
    {"cat": "cleaner", "file": "Woosh Sweep Slide Infographics Basic.wav", "verdict": "STRONG",
     "role": "sweep", "reason": "0.50 s rising airy sweep: the broom; if Büyütücü takes it, use ScratchCard wipe here instead.", "flags": ["NOISY"]},
    {"cat": "cleaner", "file": "OBJMisc_ScratchCard_SurfaceWipe_04_InMotionAudio_ScratchCard.wav", "verdict": "ALT",
     "role": "sweep: soft wipe", "reason": "1.08 s wipe, quiet (−36 dBFS RMS), centroid 6.4 kHz: airy 'brush' texture; bright but very soft.", "flags": ["BRIGHT", "NOISY"]},
    {"cat": "cleaner", "file": "FOLYClth_ClothMovement29_InMotionAudio_FoleyT-Shirt.wav", "verdict": "ALT",
     "role": "sweep: cloth swish", "reason": "1.50 s, centroid 4.6 kHz, −27 dBFS RMS: soft fabric swish, trim to 0.5 s.", "flags": ["TRIM", "NOISY"]},
    {"cat": "cleaner", "file": "Cartoon Pull Swoosh Readout.wav", "verdict": "ALT",
     "role": "sweep: cartoon swoosh", "reason": "see upgrade.", "flags": ["TRIM", "LONG"]},
    {"cat": "cleaner", "file": "Cartoon Pops Random Sequence Reverb.wav", "verdict": "STRONG",
     "role": "little pops (sequence)", "reason": "1.40 s of small pops ~900 Hz with light reverb, transient 126 dB/10 ms: either the whole cascade under the sweep, or sliced into 3-4 single pops for the per-piece `clear_puff`.", "flags": ["TRIM"]},
    {"cat": "cleaner", "file": "select_001.ogg", "verdict": "STRONG",
     "role": "single tiny pop", "reason": "0.04 s tick at 2.3 kHz: with ±8 % pitch jitter and 45 ms cooldown it reads as popcorn."},
    {"cat": "cleaner", "file": "click_001.ogg", "verdict": "STRONG",
     "role": "single soft pop", "reason": "0.10 s, centroid 1.0 kHz, −26 dBFS RMS (quiet): softer than select_001."},
    {"cat": "cleaner", "file": "impactGeneric_light_003.ogg", "verdict": "ALT",
     "role": "single pop (body family, pitched up 1.3×)", "reason": "keeps the pops in the merge material family."},
    {"cat": "cleaner", "file": "drop_001.ogg", "verdict": "ALT",
     "role": "single pop, brighter", "reason": "0.11 s, centroid 3.0 kHz, 19 % > 4 kHz.", "flags": ["BRIGHT"]},
    {"cat": "cleaner", "file": "GAMEBoard_Game Play Piece Action Organic Connect Dots Fall Bounce 04_ESM_BG.wav", "verdict": "ALT",
     "role": "single pop, wooden", "reason": "0.22 s, transient 212 dB/10 ms (sharp), centroid 5.6 kHz.", "flags": ["FATIGUE", "BRIGHT"]},

    # ---------------- M. DANGER pulse ----------------
    {"cat": "danger", "file": "bong_001.ogg", "verdict": "STRONG",
     "role": "soft low tick (every 0.5 s)", "reason": "0.12 s pure 237 Hz 'bong', no transient: quiet enough to repeat twice a second without becoming a siren."},
    {"cat": "danger", "file": "question_004.ogg", "verdict": "STRONG",
     "role": "two-note descending warning", "reason": "495→334 Hz (−7 st), 0.33 s, tonal: the 'soft two-note' the spec asks for; at −10 dB and 0.5 s interval."},
    {"cat": "danger", "file": "question_002.ogg", "verdict": "ALT",
     "role": "two-note, higher", "reason": "786→528 Hz, 0.33 s."},
    {"cat": "danger", "file": "error_008.ogg", "verdict": "ALT",
     "role": "muted low bonk", "reason": "0.14 s, 108 Hz + mids (centroid 372 Hz), transient 34."},
    {"cat": "danger", "file": "Interface Percussion Snap.wav", "verdict": "ALT",
     "role": "percussive tick", "reason": "0.66 s, centroid 497 Hz, 152 Hz fundamental, quiet: drum-like pulse."},
    {"cat": "danger", "file": "switch_006.ogg", "verdict": "ALT",
     "role": "low click", "reason": "eff 0.14 s, centroid 289 Hz; transient 179 dB/10 ms — a real click, may be too sharp when repeated.", "flags": ["FATIGUE"]},
    {"cat": "danger", "file": "Interface Deny Low Fat Dark.wav", "verdict": "ALT",
     "role": "dark pulse", "reason": "0.74 s, 205→574 Hz, transient 178: 'dark' may push past cozy into horror.", "flags": ["FATIGUE"]},

    # ---------------- N/O. WIN / FAIL (+ revive note) ----------------
    {"cat": "win_fail", "file": "jingles_PIZZI04.ogg", "verdict": "STRONG",
     "role": "WIN: short rising pizzicato", "reason": "221→371 Hz (+9 st), 0.56 s, centroid 326 Hz: cute, short, warm; same family as the current lose jingle."},
    {"cat": "win_fail", "file": "jingles_STEEL09.ogg", "verdict": "STRONG",
     "role": "WIN: steel-drum riser", "reason": "334→592 Hz (+10 st), 0.59 s: warm tropical-cozy; different colour from pizzicato."},
    {"cat": "win_fail", "file": "Game Entry Happy Short.wav", "verdict": "STRONG",
     "role": "WIN: designed happy sting", "reason": "445→1043 Hz, 0.88 s, tonal: purpose-built casual 'yay'."},
    {"cat": "win_fail", "file": "jingles_PIZZI07.ogg", "verdict": "ALT",
     "role": "WIN: CURRENT (1.32 s)", "reason": "350→293 Hz, 1.32 s: longest of the set; kept for A/B."},
    {"cat": "win_fail", "file": "jingles_PIZZI02.ogg", "verdict": "ALT",
     "role": "WIN: rising, longer", "reason": "264→417 Hz (+8 st), 0.96 s."},
    {"cat": "win_fail", "file": "jingles_STEEL02.ogg", "verdict": "ALT",
     "role": "WIN: steel-drum phrase", "reason": "299→471 Hz (+8 st), 1.39 s.", "flags": ["LONG"]},
    {"cat": "win_fail", "file": "jingles_PIZZI10.ogg", "verdict": "ALT",
     "role": "WIN: rising", "reason": "293→393 Hz (+5 st), 0.80 s."},
    {"cat": "win_fail", "file": "TOONMisc_Bird Flutes 3_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "WIN: flute trill", "reason": "1.03 s cute flute; novelty risk.", "flags": ["FATIGUE"]},
    {"cat": "win_fail", "file": "UIMisc_Xylophone Ringtone 2_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "WIN: xylophone phrase", "reason": "4.11 s — a ringtone-length melody; only the first bar (~1.2 s) could serve.", "flags": ["TRIM", "LONG"]},
    {"cat": "win_fail", "file": "jingles_PIZZI05.ogg", "verdict": "STRONG",
     "role": "FAIL: descending pizzicato", "reason": "371→221 Hz (−9 st), 0.54 s: 'hayır ya' without a buzzer; mirror of PIZZI04."},
    {"cat": "win_fail", "file": "jingles_PIZZI00.ogg", "verdict": "STRONG",
     "role": "FAIL: descending, softer", "reason": "463→312 Hz (−7 st), 0.49 s, −6 dBFS peak (quietest pizzicato)."},
    {"cat": "win_fail", "file": "jingles_PIZZI16.ogg", "verdict": "ALT",
     "role": "FAIL: CURRENT round_lose", "reason": "312 Hz flat contour, 0.46 s: kept for A/B."},
    {"cat": "win_fail", "file": "jingles_STEEL05.ogg", "verdict": "ALT",
     "role": "FAIL: steel-drum descent", "reason": "374→223 Hz (−9 st), 0.94 s."},
    {"cat": "win_fail", "file": "Interface Arp Reveal Down Long.wav", "verdict": "ALT",
     "role": "FAIL / taşma: descending arp", "reason": "5974→838 Hz (−34 st), 1.17 s, centroid 4.9 kHz: a soft 'deflating' arp; bright start.", "flags": ["BRIGHT"]},
    {"cat": "win_fail", "file": "Cartoon Transition Bass Down.wav", "verdict": "ALT",
     "role": "taşma (fail moment): down-wobble", "reason": "568→190 Hz, trim to 0.7 s.", "flags": ["TRIM", "LONG"]},
    {"cat": "win_fail", "file": "jingles_HIT14.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "orchestral hit (+52 st sweep, flatness 0.017): dramatic trailer language, wrong for cozy.", "flags": ["FATIGUE"]},
    {"cat": "win_fail", "file": "jingles_NES03.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "8-bit chiptune — explicitly excluded by AUDIO_ASSET_REQUIREMENTS."},
    {"cat": "win_fail", "file": "jingles_SAX05.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "lounge saxophone: off-tone for kawaii dumplings (and −10 dBFS peak)."},

    # ---------------- P/Q/R/S. REWARDS ----------------
    {"cat": "rewards", "file": "MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav", "verdict": "STRONG",
     "role": "P chest open: latch", "reason": "0.38 s latch click + thunk, centroid 4.5 kHz but 25 % < 200 Hz (click + body), 192 kHz: reads as 'lid unlocks'."},
    {"cat": "rewards", "file": "CLOTHFlp_Action Inventory Open Flip Cloth Canvas Bag Slide Light 02_ESM_FG2.wav", "verdict": "STRONG",
     "role": "P chest open: soft lid", "reason": "0.69 s soft cloth flip: a gentle 'opens' if the latch is too mechanical.", "flags": ["NOISY"]},
    {"cat": "rewards", "file": "open_002.ogg", "verdict": "ALT",
     "role": "P chest open: CURRENT family", "reason": "Kenney Interface open: 0.31 s, centroid 8.2 kHz, 74 % > 4 kHz — a hissy whoosh; the shipped open_001 is even brighter (12.6 kHz).", "flags": ["BRIGHT"]},
    {"cat": "rewards", "file": "SBmb_Music Box C Wind Up 006.wav", "verdict": "ALT",
     "role": "P chest open: wind-up", "reason": "1.59 s ratchet wind, centroid 8.3 kHz, 69 % > 4 kHz: charming idea, bright.", "flags": ["BRIGHT", "TRIM"]},
    {"cat": "rewards", "file": "maximize_008.ogg", "verdict": "ALT",
     "role": "P chest open: rising reveal tone", "reason": "269→409 Hz, 0.23 s."},
    {"cat": "rewards", "file": "Ting Coins.wav", "verdict": "STRONG",
     "role": "Q dough reward", "reason": "1.10 s coin ting, 246 Hz body + 1.5 kHz ring, transient 188 dB/10 ms: a clear 'currency' cue; play once per reveal, not per Hamur."},
    {"cat": "rewards", "file": "confirmation_001.ogg", "verdict": "ALT",
     "role": "Q dough reward: two-note up", "reason": "388→1174 Hz, 0.29 s, warm (centroid 531 Hz): shares the UI confirm family — cheaper, cohesive."},
    {"cat": "rewards", "file": "Foley Coin Flip Single Fast.wav", "verdict": "ALT",
     "role": "Q dough reward: coin flip", "reason": "0.94 s, −31 dBFS RMS (very quiet), flatness 0.82 (noisy): realistic coin, may sound thin.", "flags": ["NOISY"]},
    {"cat": "rewards", "file": "Button Arp Twinkle.wav", "verdict": "STRONG",
     "role": "R skin unlock", "reason": "rising twinkle arp 1.81 s: 'something new' — longer than a merge sparkle is fine here (once per reveal).", "flags": ["BRIGHT"]},
    {"cat": "rewards", "file": "Interface Plucks Happy.wav", "verdict": "STRONG",
     "role": "R skin unlock / Rare", "reason": "0.85 s happy plucks: warmer alternative."},
    {"cat": "rewards", "file": "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "R Rare reveal", "reason": "0.55 s kalimba up."},
    {"cat": "rewards", "file": "Game Entry Happy Short.wav", "verdict": "ALT",
     "role": "R Epic reveal", "reason": "0.88 s two-note."},
    {"cat": "rewards", "file": "confirmation_002.ogg", "verdict": "ALT",
     "role": "R Epic reveal: rising", "reason": "+19 st, 0.54 s."},
    {"cat": "rewards", "file": "Cofetti Whoosh Pluck Spill.wav", "verdict": "STRONG",
     "role": "S Legendary", "reason": "2.54 s whoosh + plucks + spill, 659→1037 Hz, 16 % > 4 kHz: the one designed 'celebration' that is not a jackpot; trim tail to ~1.2 s.", "flags": ["TRIM"]},
    {"cat": "rewards", "file": "SBmb_Music Box A 013.wav", "verdict": "STRONG",
     "role": "S Legendary: music box", "reason": "2.84 s music-box phrase: premium-cute; use once per Legendary (3 % of chests) so it never wears.", "flags": ["TRIM", "LONG"]},
    {"cat": "rewards", "file": "GAMEMisc_Magic Creation 23_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "S Legendary: magic bloom", "reason": "3.19 s magical texture; trim.", "flags": ["TRIM", "LONG", "NOISY"]},
    {"cat": "rewards", "file": "SBmb_Music Box B 028.wav", "verdict": "ALT",
     "role": "S Legendary: music box, brighter", "reason": "1324→440 Hz phrase, 2.64 s, 23 % > 4 kHz.", "flags": ["BRIGHT", "TRIM", "LONG"]},
    {"cat": "rewards", "file": "MAGAngl_Magic Light Spell Enchantment Potion Effect Tonal Bright 03_ESM_FG2.wav", "verdict": "ALT",
     "role": "S Legendary: tonal spell", "reason": "5.20 s; first 1 s only.", "flags": ["TRIM", "LONG"]},
    {"cat": "rewards", "file": "DSGNStngr_Power Up Bright Positive Successful Light Saturation Crash Shimmer 05_ESM_AG.wav", "verdict": "ALT",
     "role": "S Legendary: shimmer", "reason": "see tier8.", "flags": ["BRIGHT", "NOISY"]},

    # ---------------- T/U/V/W. UI family ----------------
    {"cat": "ui", "file": "select_002.ogg", "verdict": "STRONG",
     "role": "T tap", "reason": "0.04 s, 689→2326 Hz, −16 dBFS RMS, 2 % > 4 kHz: a soft tick, not a click; the whole UI family should be built around this + back_002 + confirmation_001 (all Kenney Interface, same designer)."},
    {"cat": "ui", "file": "click2.ogg", "verdict": "STRONG",
     "role": "T tap (lower, rounder)", "reason": "Kenney UI Audio click2: 0.06 s, centroid 383 Hz, 79 % < 200 Hz: the rounder 'thock' option; phone will thin it."},
    {"cat": "ui", "file": "click_001.ogg", "verdict": "ALT",
     "role": "T tap (quiet)", "reason": "0.10 s, centroid 1.0 kHz, −26 dBFS RMS."},
    {"cat": "ui", "file": "rollover5.ogg", "verdict": "ALT",
     "role": "T tap (soft)", "reason": "0.11 s, centroid 888 Hz, −25 dBFS RMS."},
    {"cat": "ui", "file": "tick_004.ogg", "verdict": "ALT",
     "role": "T tap (bright tick)", "reason": "0.05 s, 129→3574 Hz: crisper."},
    {"cat": "ui", "file": "toggle_004.ogg", "verdict": "ALT",
     "role": "T tap / toggle", "reason": "0.07 s, 1.6→3.4 kHz, 20 % > 4 kHz.", "flags": ["BRIGHT"]},
    {"cat": "ui", "file": "confirmation_001.ogg", "verdict": "STRONG",
     "role": "U confirm", "reason": "388→1174 Hz two-note up, 0.29 s, centroid 531 Hz, decay 244 ms, −11 dBFS RMS: warm, unmistakably 'yes', not a slot machine."},
    {"cat": "ui", "file": "toggle_001.ogg", "verdict": "ALT",
     "role": "U confirm / toggle on", "reason": "0.14 s, 1.4→1.9 kHz: a lighter 'on'."},
    {"cat": "ui", "file": "Interface Accept Glassy Snap.wav", "verdict": "ALT",
     "role": "U confirm: glassy", "reason": "0.44 s, 926 Hz."},
    {"cat": "ui", "file": "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav", "verdict": "ALT",
     "role": "U confirm: kalimba (premium)", "reason": "0.55 s; risk of overlapping with the merge sparkle identity."},
    {"cat": "ui", "file": "back_002.ogg", "verdict": "STRONG",
     "role": "V close/back", "reason": "0.07 s, 215→129 Hz descending (−9 st), −16 dBFS RMS: the mirror of the tap — same family, goes down."},
    {"cat": "ui", "file": "minimize_008.ogg", "verdict": "STRONG",
     "role": "V modal close", "reason": "409→269 Hz descending, 0.23 s, tonal: pairs with maximize_008 for modal open/close."},
    {"cat": "ui", "file": "maximize_008.ogg", "verdict": "STRONG",
     "role": "modal open", "reason": "269→409 Hz rising, 0.23 s."},
    {"cat": "ui", "file": "back_003.ogg", "verdict": "ALT",
     "role": "V back (deeper drop)", "reason": "0.09 s, 344→129 Hz (−17 st)."},
    {"cat": "ui", "file": "minimize_006.ogg", "verdict": "ALT",
     "role": "V modal close (longer)", "reason": "603→269 Hz, 0.38 s."},
    {"cat": "ui", "file": "confirmation_004.ogg", "verdict": "ALT",
     "role": "V close (soft two-note down) / equip", "reason": "829→657 Hz (−4 st), 0.49 s."},
    {"cat": "ui", "file": "Deny Muted.wav", "verdict": "STRONG",
     "role": "W disabled / error", "reason": "440→217 Hz muted deny, 0.80 s, centroid 303 Hz, −13 dBFS RMS (dense): a polite 'no'."},
    {"cat": "ui", "file": "error_008.ogg", "verdict": "STRONG",
     "role": "W disabled / error (short bonk)", "reason": "0.14 s, 108 Hz + mids: the shortest polite refusal; pairs with the shake-on-tap."},
    {"cat": "ui", "file": "error_007.ogg", "verdict": "ALT",
     "role": "W error: soft thud", "reason": "0.19 s, 764 Hz."},
    {"cat": "ui", "file": "error_004.ogg", "verdict": "ALT",
     "role": "W error: descending blip", "reason": "0.10 s, 409→108 Hz (−23 st)."},
    {"cat": "ui", "file": "Interface Deny Low Fat Dark.wav", "verdict": "ALT",
     "role": "W error: dark", "reason": "0.74 s; darker than the brief."},
    {"cat": "ui", "file": "bong_001.ogg", "verdict": "ALT",
     "role": "W error: low bong", "reason": "0.12 s 237 Hz (shared with danger tick — avoid using for both)."},
    {"cat": "ui", "file": "click_004.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "10 ms click, centroid 9.4 kHz, 69 % > 4 kHz: a glitch, not a tap.", "flags": ["BRIGHT"]},
    {"cat": "ui", "file": "close_001.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "0.15 s, centroid 12.6 kHz, 97 % > 4 kHz: hiss; the shipped open_001 is its twin.", "flags": ["BRIGHT"]},
    {"cat": "ui", "file": "error_002.ogg", "verdict": "REF",
     "role": "REJECT reference", "reason": "5.8 kHz buzzer that clips at +0.58 dBFS: the harsh error the brief forbids.", "flags": ["BRIGHT"]},
]
# fmt: on

CATEGORY_ORDER = ["drop", "merge_body", "sparkle", "large_merge", "tier8", "bomb",
                  "upgrade", "shake", "cleaner", "danger", "win_fail", "rewards", "ui"]
CATEGORY_TITLE = {
    "drop": "A. Drop / first impact (+ release tick)",
    "merge_body": "B. Merge soft body",
    "sparkle": "C. Merge sparkle / chime (+ F. combo)",
    "large_merge": "D. Large merge body (T5-T7)",
    "tier8": "E. Tier 8 bloom",
    "bomb": "G. Bomba launch / impact",
    "upgrade": "H/I. Büyütücü charge / transform",
    "shake": "J. Sarsıntı low pulse",
    "cleaner": "K/L. Temizleyici sweep / little pops",
    "danger": "M. Danger pulse",
    "win_fail": "N/O. Win / Fail",
    "rewards": "P/Q/R/S. Chest / Dough / Skin / Legendary",
    "ui": "T/U/V/W. UI tap / confirm / close / error",
}
VERDICT_RANK = {"STRONG": 0, "ALT": 1, "REF": 2}


def db(x: float) -> float:
    return 20.0 * math.log10(max(x, 1e-9))


def resolve(inventory: list[dict]) -> dict[str, dict]:
    by_name: dict[str, list[dict]] = {}
    for r in inventory:
        by_name.setdefault(r["filename"], []).append(r)
    out = {}
    for name, rows in by_name.items():
        out[name] = rows
    return out


def normalise(src: Path, dst: Path) -> dict:
    """Audition copy: trim, fade, RMS-match, 16-bit PCM, original sr/channels."""
    data, sr = sf.read(str(src), dtype="float32", always_2d=True)
    n = data.shape[0]
    if n == 0:
        raise ValueError("empty")
    mono = data.mean(axis=1)
    win = max(int(sr * 0.005), 1)
    nf = max(n // win, 1)
    env = np.sqrt(np.mean(mono[: nf * win].reshape(nf, win) ** 2, axis=1))
    env_db = 20.0 * np.log10(np.maximum(env, 1e-9))
    peak_env = float(env_db.max())
    lead_idx = np.where(env_db > TRIM_LEAD_DB)[0]
    tail_idx = np.where(env_db > TRIM_TAIL_DB)[0]
    start = max(int(lead_idx[0] * win - LEAD_PREROLL_S * sr), 0) if lead_idx.size else 0
    end = min(int((tail_idx[-1] + 1) * win + TAIL_KEEP_S * sr), n) if tail_idx.size else n
    seg = data[start:end].copy()
    m = seg.shape[0]
    fi = min(int(FADE_IN_S * sr), m // 2)
    fo = min(int(FADE_OUT_S * sr), m // 2)
    if fi > 0:
        seg[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)[:, None]
    if fo > 0:
        seg[-fo:] *= np.linspace(1.0, 0.0, fo, dtype=np.float32)[:, None]
    smono = seg.mean(axis=1)
    nf2 = max(len(smono) // win, 1)
    env2 = np.sqrt(np.mean(smono[: nf2 * win].reshape(nf2, win) ** 2, axis=1))
    active = env2 > 10 ** (-60.0 / 20.0)
    rms = float(np.sqrt(np.mean(env2[active] ** 2))) if active.any() else float(np.sqrt(np.mean(smono ** 2)))
    gain_db = TARGET_RMS_DBFS - db(rms)
    peak = float(np.max(np.abs(seg)))
    if db(peak) + gain_db > PEAK_CEILING_DBFS:
        gain_db = PEAK_CEILING_DBFS - db(peak)
    seg *= 10 ** (gain_db / 20.0)
    dst.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(dst), seg, sr, subtype="PCM_16")
    return {
        "trim_start_s": round(start / sr, 3),
        "trim_end_s": round(end / sr, 3),
        "audition_len_s": round(m / sr, 3),
        "audition_gain_db": round(gain_db, 2),
        "peak_env_dbfs": round(peak_env, 2),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=SOURCE_DEFAULT)
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--zip", action="store_true", help="also build the review bundle zip")
    ap.add_argument("--no-normalized", action="store_true")
    args = ap.parse_args()
    source = Path(args.source)
    out = Path(args.out)
    inv_path = out / "AUDIO_SOURCE_INVENTORY.json"
    if not inv_path.exists():
        print(f"missing {inv_path} — run tools/audio_source_audit.py first", file=sys.stderr)
        return 2
    inventory = json.load(open(inv_path, encoding="utf-8"))
    by_name = resolve(inventory)

    aud = out / "auditions"
    aud_n = out / "auditions_normalized"
    for d in (aud, aud_n):
        if d.exists():
            shutil.rmtree(d)
    aud.mkdir(parents=True)
    if not args.no_normalized:
        aud_n.mkdir(parents=True)

    problems: list[str] = []
    per_cat: dict[str, list[dict]] = {c: [] for c in CATEGORY_ORDER}
    for e in SHORTLIST:
        rows = by_name.get(e["file"])
        if not rows:
            problems.append(f"not in inventory: {e['file']}")
            continue
        if len(rows) > 1:
            problems.append(f"ambiguous filename: {e['file']} ({len(rows)} matches)")
            continue
        if e["cat"] not in per_cat:
            problems.append(f"unknown category {e['cat']} for {e['file']}")
            continue
        per_cat[e["cat"]].append({**e, "row": rows[0]})
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1

    manifest: list[dict] = []
    order_lines = ["# M8.8-01 — Listening order", "",
                   "Numbers are the recommended order inside each folder (STRONG first, then ALT, then REF).",
                   "`auditions/` = untouched originals. `auditions_normalized/` = same files trimmed + gain-matched",
                   f"to {TARGET_RMS_DBFS:.0f} dBFS RMS for fair comparison (listening only, NOT production processing).",
                   "Flags: PHONE = relies on sub-bass/width that a phone speaker drops · FATIGUE = sharp transient or",
                   "recognisable tail on repeat · TRIM = needs trimming to be usable · BRIGHT = high-frequency share",
                   "may pierce · LONG = too long as-is · NOISY = noise-based rather than tonal.", ""]
    total_bytes = 0
    for cat in CATEGORY_ORDER:
        entries = per_cat[cat]
        entries.sort(key=lambda e: VERDICT_RANK[e["verdict"]])
        cat_dir = aud / cat
        cat_dir.mkdir(parents=True, exist_ok=True)
        index_rows = []
        order_lines.append(f"## {cat}/ — {CATEGORY_TITLE[cat]}")
        order_lines.append("")
        order_lines.append("| # | verdict | file | pack | role | reason | flags |")
        order_lines.append("|---|---|---|---|---|---|---|")
        for i, e in enumerate(entries, 1):
            r = e["row"]
            src = source / r["rel_path"]
            stem = f"{i:02d}_{Path(r['filename']).stem}"
            dst = cat_dir / f"{i:02d}_{r['filename']}"
            shutil.copy2(src, dst)
            total_bytes += dst.stat().st_size
            norm = {}
            if not args.no_normalized:
                try:
                    norm = normalise(src, aud_n / cat / f"{stem}.wav")
                except Exception as exc:  # noqa: BLE001
                    norm = {"normalize_error": f"{type(exc).__name__}: {exc}"}
            pack_label = r["pack"] if not r.get("library") else f"Sonniss / {r['supplier']} — {r['library']}"
            rec = {
                "category": cat, "order": i, "verdict": e["verdict"], "audition_file": dst.name,
                "source_pack": r["pack"], "source_library": r.get("library", ""),
                "source_supplier": r.get("supplier", ""), "source_url": r.get("library_url", ""),
                "source_rel_path": r["rel_path"], "license": r["license"], "role": e["role"],
                "reason": e["reason"], "flags": " ".join(e.get("flags", [])),
                "duration_s": r.get("duration_s"), "samplerate": r.get("samplerate"),
                "channels": r.get("channels"), "bit_depth": r.get("bit_depth"),
                "peak_dbfs": r.get("peak_dbfs"), "rms_active_dbfs": r.get("rms_active_dbfs"),
                "spectral_centroid_hz": r.get("spectral_centroid_hz"),
                "share_low_200hz": r.get("share_low_200hz"), "share_high_4k_plus": r.get("share_high_4k_plus"),
                "transient_db_per_10ms": r.get("transient_db_per_10ms"), "effective_len_s": r.get("effective_len_s"),
                "f0_start_hz": r.get("f0_start_hz"), "f0_end_hz": r.get("f0_end_hz"),
                "pitch_dir_semitones": r.get("pitch_dir_semitones"), **norm,
            }
            index_rows.append(rec)
            manifest.append(rec)
            order_lines.append(
                f"| {i:02d} | {e['verdict']} | `{r['filename']}` | {pack_label} | {e['role']} | {e['reason']} | {' '.join(e.get('flags', []))} |")
        order_lines.append("")
        with open(cat_dir / "index.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(index_rows[0].keys()) if index_rows else ["category"])
            w.writeheader()
            for rec in index_rows:
                w.writerow(rec)

    with open(out / "SHORTLIST.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    with open(out / "LISTENING_ORDER.md", "w", encoding="utf-8") as f:
        f.write("\n".join(order_lines))
    uniq = {m["source_rel_path"] for m in manifest}
    counts = {c: {v: sum(1 for m in manifest if m["category"] == c and m["verdict"] == v) for v in VERDICT_RANK}
              for c in CATEGORY_ORDER}
    print(f"shortlist entries: {len(manifest)}  unique files: {len(uniq)}  originals: {total_bytes / 1e6:.1f} MB")
    for c, v in counts.items():
        print(f"  {c:12} STRONG {v['STRONG']:2}  ALT {v['ALT']:2}  REF {v['REF']:2}")

    if args.zip:
        zpath = out / "M8.8-01_audio_review_bundle.zip"
        docs = ["FINAL_AUDIO_PALETTE.md", "MERGE_SOUND_FAMILY_BLUEPRINT.md", "AUDIO_SOURCE_PROVENANCE.md",
                "HAPTIC_ALIGNMENT.md", "LISTENING_ORDER.md", "SHORTLIST.json"]
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for d in docs:
                p = out / d
                if p.exists():
                    z.write(p, d)
                else:
                    print(f"  (bundle) missing doc: {d}")
            for base in (aud, aud_n):
                if not base.exists():
                    continue
                for p in sorted(base.rglob("*")):
                    if p.is_file():
                        z.write(p, str(p.relative_to(out)).replace("\\", "/"))
        print(f"bundle: {zpath} ({zpath.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
