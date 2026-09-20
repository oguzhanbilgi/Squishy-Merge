#!/usr/bin/env python
"""audio_production_build.py — M8.8-02 production SFX build (offline, once).

Turns the owner-approved sources from the M8.8-01 audit pool into the final
production files under `assets/audio/sfx/<ui|gameplay|powers|rewards>/`:

    WAV · 44.1 kHz · 16-bit · mono · no loop · head silence <= 5 ms ·
    2 ms fade-in · click-free fade-out · peak -4 dBFS reference

Processing is deliberately minimal and declared per file in RECIPES below
(trim, one high-pass, one low-pass, fades, peak). Nothing creative is
re-synthesised; the mix lives in `AudioManager.EVENTS` gain_db, not here.
Sources are read from the owner-local library (D:\\dev\\squishy-audio-source,
outside the repo, never modified) and converted ONCE — do not re-run this on
top of already-built files as a habit; it is deterministic, so a re-run only
matters when a recipe changes.

Provenance (pack / library / licence) is embedded per recipe so the script
does not depend on the gitignored `build/qa_m8.8-01/` inventory. The
manifest it writes (`docs/audio/PRODUCTION_FILES.md`) is the generated
source of truth for `assets/audio/CREDITS.md` and `docs/audio/AUDIO_SYSTEM.md`.

Usage (isolated venv from M8.8-01: numpy + soundfile, no ffmpeg/sox):

    D:\\dev\\squishy-audio-source\\.venv\\Scripts\\python.exe tools/audio_production_build.py
        [--source D:\\dev\\squishy-audio-source] [--out assets/audio/sfx]
        [--manifest docs/audio/PRODUCTION_FILES.md] [--only sfx_merge_pop]

After building, import once in Godot (`--headless --import`) so the `.import`
files exist, then run `tools/audio_test.tscn` and `tools/audio_probe.gd`.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True

SOURCE_DEFAULT = r"D:\dev\squishy-audio-source"
OUT_DEFAULT = "assets/audio/sfx"
MANIFEST_DEFAULT = "docs/audio/PRODUCTION_FILES.md"

TARGET_SR = 44100
PEAK_DBFS = -4.0
HEAD_KEEP_S = 0.001        # pre-roll kept before the first active sample
HEAD_DB = -50.0            # "active" threshold for head trim (dBFS, 1 ms RMS)
TAIL_DB = -54.0            # tail trim threshold (dBFS, 5 ms RMS, after peak normalise)
TAIL_KEEP_S = 0.030        # kept after the last active window, before the fade-out
FADE_IN_S = 0.002

# Licence strings (read from the files shipped in the packs — see
# build/qa_m8.8-01/AUDIO_SOURCE_PROVENANCE.md and docs/licenses/).
KENNEY_IMPACT = ("Kenney Impact Sounds 1.0", "Kenney (www.kenney.nl)", "CC0 1.0", "kenney-impact/Audio/")
KENNEY_UI = ("Kenney Interface Sounds 1.0", "Kenney (www.kenney.nl)", "CC0 1.0", "kenney-interface/Audio/")
KENNEY_JINGLES_STEEL = ("Kenney Music Jingles", "Kenney Vleugels (Kenney.nl)", "CC0 1.0", "kenney-jingles/Audio/Steel jingles/")
KENNEY_JINGLES_PIZZI = ("Kenney Music Jingles", "Kenney Vleugels (Kenney.nl)", "CC0 1.0", "kenney-jingles/Audio/Pizzicato jingles/")
SONNISS = "Sonniss GDC 2026 royalty-free EULA (commercial, no attribution, no AI use)"


def son(library: str, supplier: str, folder: str) -> tuple[str, str, str, str]:
    return (library, supplier, SONNISS, "sonniss-gdc-2026/%s/" % folder)


CSD = "Cinematic Sound Design"
CSD_UI_INTERACTION = son("UI Interaction Elements", CSD, "Cinematic Sound Design - UI Interaction Elements")
CSD_CARTOON2 = son("Cartoon & Animation Vol 2", CSD, "Cinematic Sound Design - Cartoon & Animation Vol 2")
CSD_CARTOON_IMPACTS = son("Cartoon Impacts", CSD, "Cinematic Sound Design - Cartoon Impacts")
CSD_ULTRA = son("Ultra Transitions & Impacts", CSD, "Cinematic Sound Design - Ultra Transitions & Impacts")
CSD_USER_INTERFACE = son("User Interface", CSD, "Cinematic Sound Design - User Interface")
SONIC_BAT_BOXES = son("Music Boxes", "Sonic Bat", "Sonic Bat - Music Boxes")
ESM_LOCK = son("HD Lock And Mechanism Sound Design Kit", "Epic Stock Media",
               "Epic Stock Media - HD Lock And Mechanism Sound Design Kit")

# fmt: off
# One entry per production file. Keys:
#   out        production path under assets/audio/sfx
#   src        source filename (looked up inside pack folder)
#   pack       (pack/library, publisher/supplier, licence, folder)
#   role       what the runtime uses it for (event ids)
#   owner      owner decision reference (M8.8-02 brief)
#   trim       (start_s, end_s) in the SOURCE timeline, None = whole file
#   hp / lp    2nd-order Butterworth cut-off Hz (None = none)
#   fade_out   seconds (applied to the end of the trimmed/tail-trimmed segment)
#   fade_in    seconds (default FADE_IN_S)
#   tail_db    tail-trim threshold override (dBFS)
#   peak       peak override (dBFS) — the two POP bubbles are RMS-matched
#              (-6.5 / -3.0) so consecutive merges do not jump 4 dB
RECIPES: list[dict] = [
    # ---------------- MERGE FAMILY — owner approved A (premium) ----------------
    {"out": "gameplay/sfx_merge_pop_01.wav", "src": "Cartoon Bubbles Short.wav", "pack": CSD_CARTOON2,
     "role": "merge (POP core, tier pitch 0.85→1.48×) — bubble 1 of the source", "owner": "MERGE A — BODY A",
     "trim": (0.0, 0.200), "hp": 120, "lp": None, "fade_out": 0.030, "peak": -6.5},
    {"out": "gameplay/sfx_merge_pop_02.wav", "src": "Cartoon Bubbles Short.wav", "pack": CSD_CARTOON2,
     "role": "merge (POP core) — bubble 2 of the same source, natural variant", "owner": "MERGE A — BODY A",
     "trim": (0.215, 0.500), "hp": 120, "lp": None, "fade_out": 0.040, "peak": -3.0},
    {"out": "gameplay/sfx_merge_body_light_01.wav", "src": "impactGeneric_light_002.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_body_light (T1–T3)", "owner": "MERGE A — BODY B",
     "trim": None, "hp": 100, "lp": None, "fade_out": 0.020},
    {"out": "gameplay/sfx_merge_body_light_02.wav", "src": "impactGeneric_light_004.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_body_light (T1–T3) variant", "owner": "MERGE A — BODY B sibling (blueprint pool)",
     "trim": None, "hp": 100, "lp": None, "fade_out": 0.020},
    {"out": "gameplay/sfx_merge_body_full_01.wav", "src": "impactPlate_light_003.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_body_full (T4–T6)", "owner": "MERGE A — BODY C",
     "trim": (0.0, 0.35), "hp": 120, "lp": None, "fade_out": 0.060},
    {"out": "gameplay/sfx_merge_body_full_02.wav", "src": "impactPlate_medium_001.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_body_full (T4–T6) variant", "owner": "MERGE A — LARGE BODY B",
     "trim": (0.0, 0.35), "hp": 120, "lp": None, "fade_out": 0.060},
    {"out": "gameplay/sfx_merge_body_large_01.wav", "src": "impactPunch_medium_001.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_body_large (T7–T8), annihilation body", "owner": "MERGE A — LARGE BODY A",
     "trim": (0.0, 0.40), "hp": 110, "lp": 6000, "fade_out": 0.060},
    {"out": "gameplay/sfx_merge_sparkle_01.wav", "src": "impactGlass_light_002.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_sparkle (T3+), combo, star_reveal", "owner": "MERGE A — SPARKLE A",
     "trim": None, "hp": None, "lp": 8000, "fade_out": 0.030},
    {"out": "gameplay/sfx_merge_sparkle_02.wav", "src": "impactGlass_light_000.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_sparkle variant", "owner": "MERGE A — SPARKLE A sibling (blueprint pool)",
     "trim": None, "hp": None, "lp": 8000, "fade_out": 0.030},
    {"out": "gameplay/sfx_merge_sparkle_03.wav", "src": "impactGlass_light_004.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_sparkle variant", "owner": "MERGE A — SPARKLE A sibling (blueprint pool)",
     "trim": None, "hp": None, "lp": 8000, "fade_out": 0.030},
    {"out": "gameplay/sfx_merge_chime_01.wav", "src": "impactBell_heavy_002.ogg", "pack": KENNEY_IMPACT,
     "role": "merge_chime (T5–T7)", "owner": "MERGE A — CHIME T5-7",
     "trim": (0.0, 0.50), "hp": 150, "lp": None, "fade_out": 0.080},
    {"out": "rewards/sfx_tier8_bloom_01.wav", "src": "impactBell_heavy_000.ogg", "pack": KENNEY_IMPACT,
     "role": "tier_max (T8 bloom), reward_legendary bloom", "owner": "MERGE A — T8 BLOOM A",
     "trim": (0.0, 1.10), "hp": 150, "lp": None, "fade_out": 0.120},
    {"out": "rewards/sfx_tier8_box_01.wav", "src": "SBmb_Music Box A 013.wav", "pack": SONIC_BAT_BOXES,
     "role": "tier_max_box (T8 music-box note), reward_epic / reward_legendary note", "owner": "MERGE A — T8 BLOOM B (note)",
     "trim": (0.0, 0.55), "hp": None, "lp": 10000, "fade_out": 0.150},
    {"out": "rewards/sfx_tier8_tail_01.wav", "src": "Button Arp Twinkle.wav", "pack": CSD_USER_INTERFACE,
     "role": "tier_max_tail (T8 twinkle), reward_rare, reward_epic/legendary tail, level_unlock", "owner": "MERGE A — T8 TAIL A",
     "trim": (0.0, 0.60), "hp": None, "lp": 8000, "fade_out": 0.100},

    # ---------------- DROP — owner approved C ----------------
    {"out": "gameplay/sfx_land_01.wav", "src": "impactGeneric_light_001.ogg", "pack": KENNEY_IMPACT,
     "role": "land (landing, pitch by tier / gain by speed), drop (release tick, 1.35×, quieter)", "owner": "DROP C",
     "trim": None, "hp": 120, "lp": None, "fade_out": 0.020},

    # ---------------- BOMBA — owner approved A ----------------
    {"out": "powers/sfx_bomb_launch_01.wav", "src": "minimize_006.ogg", "pack": KENNEY_UI,
     "role": "bomb_whoosh (launch, falling tone)", "owner": "BOMBA A — launch",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.030},
    {"out": "powers/sfx_bomb_impact_01.wav", "src": "impactPunch_medium_000.ogg", "pack": KENNEY_IMPACT,
     "role": "bomb_impact (compact body/pop)", "owner": "BOMBA A — impact",
     "trim": (0.0, 0.40), "hp": 110, "lp": None, "fade_out": 0.060},
    {"out": "powers/sfx_bomb_poof_01.wav", "src": "footstep_snow_000.ogg", "pack": KENNEY_IMPACT,
     "role": "bomb_poof (+15 ms soft poof layer)", "owner": "BOMBA A — poof",
     "trim": (0.0, 0.30), "hp": 150, "lp": 7000, "fade_out": 0.060},

    # ---------------- BÜYÜTÜCÜ — owner approved C (minimal relaxed) ----------------
    {"out": "powers/sfx_upgrade_charge_01.wav", "src": "maximize_006.ogg", "pack": KENNEY_UI,
     "role": "upgrade (tap response, rising tone through the 150 ms anticipation)", "owner": "BÜYÜTÜCÜ C — charge",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.030},
    {"out": "powers/sfx_upgrade_air_01.wav", "src": "Woosh Sweep Slide Infographics Basic.wav", "pack": CSD_ULTRA,
     "role": "upgrade_transform (restrained airy sweep at the transform, under the merge-family sound)", "owner": "BÜYÜTÜCÜ C — air",
     "trim": (0.0, 0.30), "hp": 200, "lp": 9000, "fade_out": 0.060},

    # ---------------- SARSINTI — Claude's choice (owner rejected A/B/C) ----------------
    {"out": "powers/sfx_shake_01.wav", "src": "Accept Boing Crunch.wav", "pack": CSD_UI_INTERACTION,
     "role": "shake (jelly wobble: warbling 375–1100 Hz tone, cut before the source's final 1.5 kHz ping)", "owner": "SARSINTI — Claude pick",
     "trim": (0.015, 0.470), "hp": 150, "lp": 7000, "fade_in": 0.008, "fade_out": 0.070},

    # ---------------- TEMİZLEYİCİ — owner preferred B (pop character) ----------------
    {"out": "powers/sfx_clear_sweep_01.wav", "src": "Cartoon Pull Swoosh Readout.wav", "pack": CSD_CARTOON2,
     "role": "clear_sweep (subtle activation sweep underneath)", "owner": "TEMİZLEYİCİ B — sweep under",
     "trim": (0.060, 0.420), "hp": 300, "lp": 9000, "fade_in": 0.010, "fade_out": 0.080},
    {"out": "powers/sfx_clear_pop_01.wav", "src": "Cartoon Pops Random Sequence Reverb.wav", "pack": CSD_CARTOON_IMPACTS,
     "role": "clear_puff (per removed piece, existing stagger) — pop 1 sliced from the dry part of the sequence", "owner": "TEMİZLEYİCİ B — pops",
     "trim": (0.003, 0.048), "hp": 150, "lp": 9000, "fade_out": 0.008},
    {"out": "powers/sfx_clear_pop_02.wav", "src": "Cartoon Pops Random Sequence Reverb.wav", "pack": CSD_CARTOON_IMPACTS,
     "role": "clear_puff — pop 2", "owner": "TEMİZLEYİCİ B — pops",
     "trim": (0.073, 0.135), "hp": 150, "lp": 9000, "fade_out": 0.010},
    {"out": "powers/sfx_clear_pop_03.wav", "src": "Cartoon Pops Random Sequence Reverb.wav", "pack": CSD_CARTOON_IMPACTS,
     "role": "clear_puff — pop 3", "owner": "TEMİZLEYİCİ B — pops",
     "trim": (0.148, 0.195), "hp": 150, "lp": 9000, "fade_out": 0.008},

    # ---------------- DANGER — Claude's choice (owner rejected A/B) ----------------
    {"out": "gameplay/sfx_danger_01.wav", "src": "impactWood_light_001.ogg", "pack": KENNEY_IMPACT,
     "role": "danger (soft wooden tok every 0.5 s)", "owner": "DANGER — Claude pick",
     "trim": (0.0, 0.090), "hp": 150, "lp": 6000, "fade_out": 0.025},
    {"out": "gameplay/sfx_danger_02.wav", "src": "impactWood_light_003.ogg", "pack": KENNEY_IMPACT,
     "role": "danger variant (slightly lower tok)", "owner": "DANGER — Claude pick",
     "trim": (0.0, 0.090), "hp": 150, "lp": 6000, "fade_out": 0.025},

    # ---------------- WIN / FAIL — owner approved B / B ----------------
    {"out": "rewards/sfx_round_win_01.wav", "src": "jingles_STEEL09.ogg", "pack": KENNEY_JINGLES_STEEL,
     "role": "round_win, revive (0.9×)", "owner": "WIN B",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.060},
    {"out": "gameplay/sfx_round_lose_01.wav", "src": "jingles_PIZZI00.ogg", "pack": KENNEY_JINGLES_PIZZI,
     "role": "round_lose, fail (overflow moment, 0.94×)", "owner": "FAIL B",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.060},

    # ---------------- CHEST / REWARDS ----------------
    {"out": "rewards/sfx_chest_open_01.wav", "src": "MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav", "pack": ESM_LOCK,
     "role": "chest_open (latch, restrained)", "owner": "CHEST OPEN A (owner listening decision)",
     "trim": (0.0, 0.35), "hp": 120, "lp": 10000, "fade_out": 0.050},
    {"out": "rewards/sfx_reward_dough_01.wav", "src": "Ting Coins.wav", "pack": CSD_UI_INTERACTION,
     "role": "reward_common (Hamur / Common reveal), daily_reward (0.95×)", "owner": "DOUGH REWARD approved",
     "trim": (0.0, 0.70), "hp": 150, "lp": 10000, "fade_out": 0.100},

    # ---------------- UI FAMILY — owner approved all four (Kenney Interface Sounds) ----------------
    {"out": "ui/sfx_ui_tap_01.wav", "src": "select_002.ogg", "pack": KENNEY_UI,
     "role": "ui_tap, ui_tab (1.15×), ui_select (0.9×)", "owner": "UI TAP",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.010},
    {"out": "ui/sfx_ui_confirm_01.wav", "src": "confirmation_001.ogg", "pack": KENNEY_UI,
     "role": "ui_purchase, ui_toggle_on (1.2×), ui_equip (1.1×), ui_modal_open (0.95×), power_arm (1.15×)", "owner": "UI CONFIRM",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.040},
    {"out": "ui/sfx_ui_back_01.wav", "src": "back_002.ogg", "pack": KENNEY_UI,
     "role": "ui_modal_close (back)", "owner": "UI BACK",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.015},
    {"out": "ui/sfx_ui_error_01.wav", "src": "error_008.ogg", "pack": KENNEY_UI,
     "role": "ui_invalid", "owner": "UI ERROR",
     "trim": None, "hp": None, "lp": None, "fade_out": 0.030},
]
# fmt: on


# --- DSP helpers (numpy only; no scipy/ffmpeg on this machine) ---

def db(x: float) -> float:
    return 20.0 * np.log10(max(float(x), 1e-12))


def resample_sinc(x: np.ndarray, sr_in: int, sr_out: int, taps: int = 64, beta: float = 8.6) -> np.ndarray:
    """Windowed-sinc (Kaiser) resampler, anti-aliased, applied in chunks."""
    if sr_in == sr_out:
        return x.astype(np.float64)
    x = x.astype(np.float64)
    ratio = sr_out / sr_in
    n_out = int(round(len(x) * ratio))
    fc = min(sr_in, sr_out) * 0.5 * 0.92 / sr_in  # cycles per input sample
    half = taps // 2
    offs = np.arange(-half + 1, half + 1, dtype=np.float64)
    xp = np.pad(x, (half + 1, half + 1))
    y = np.empty(n_out)
    chunk = 16384
    i0_beta = np.i0(beta)
    for s in range(0, n_out, chunk):
        n = np.arange(s, min(s + chunk, n_out))
        t = n / ratio
        k0 = np.floor(t).astype(np.int64)
        d = (t - k0)[:, None] - offs[None, :]          # distance to each tap, in input samples
        h = 2.0 * fc * np.sinc(2.0 * fc * d)
        arg = 1.0 - (d / half) ** 2
        w = np.where(arg > 0.0, np.i0(beta * np.sqrt(np.clip(arg, 0.0, 1.0))) / i0_beta, 0.0)
        h *= w
        h /= h.sum(axis=1, keepdims=True)
        idx = (k0[:, None] + offs[None, :].astype(np.int64)) + half + 1
        y[s:s + len(n)] = (xp[idx] * h).sum(axis=1)
    return y


def biquad(x: np.ndarray, sr: int, kind: str, fc: float, q: float = 0.7071) -> np.ndarray:
    """RBJ cookbook 2nd-order Butterworth (q = 1/sqrt2) high-/low-pass, one pass."""
    w0 = 2.0 * np.pi * fc / sr
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    elif kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    else:
        raise ValueError(kind)
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = yi
        x2, x1, y2, y1 = x1, xi, y1, yi
    return y


def rms_env_db(x: np.ndarray, sr: int, win_s: float) -> tuple[np.ndarray, int]:
    w = max(int(sr * win_s), 1)
    n = max(len(x) // w, 1)
    env = np.sqrt(np.mean(x[: n * w].reshape(n, w) ** 2, axis=1))
    return 20.0 * np.log10(np.maximum(env, 1e-9)), w


def band_share(x: np.ndarray, sr: int, lo: float, hi: float) -> float:
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    freqs = np.fft.rfftfreq(len(x), 1.0 / sr)
    total = spec[freqs >= 20.0].sum() + 1e-18
    return float(spec[(freqs >= lo) & (freqs < hi)].sum() / total)


def build_one(recipe: dict, source_root: Path, out_root: Path) -> dict:
    pack_name, publisher, licence, folder = recipe["pack"]
    src = source_root / folder / recipe["src"]
    if not src.exists():
        raise FileNotFoundError(src)
    data, sr = sf.read(str(src), dtype="float64", always_2d=True)
    src_channels = data.shape[1]
    src_frames = data.shape[0]
    mono = data.mean(axis=1)

    # 1) trim in the source timeline (before resampling: sample-exact on the source)
    trim = recipe.get("trim")
    if trim is not None:
        a = int(round(trim[0] * sr))
        b = int(round(trim[1] * sr)) if trim[1] is not None else len(mono)
        mono = mono[a:min(b, len(mono))]

    # 2) resample once to 44.1 kHz
    y = resample_sinc(mono, sr, TARGET_SR)
    sr2 = TARGET_SR

    # 3) filters (one HP, one LP at most)
    if recipe.get("hp"):
        y = biquad(y, sr2, "hp", float(recipe["hp"]))
    if recipe.get("lp"):
        y = biquad(y, sr2, "lp", float(recipe["lp"]))

    # 4) peak reference before trims so thresholds are absolute dBFS
    peak = float(np.max(np.abs(y))) if len(y) else 0.0
    target = 10 ** (recipe.get("peak", PEAK_DBFS) / 20.0)
    gain = target / max(peak, 1e-9)
    y = y * gain

    # 5) head trim: first 1 ms window above HEAD_DB, keep HEAD_KEEP_S pre-roll
    env, w = rms_env_db(y, sr2, 0.001)
    active = np.where(env > HEAD_DB)[0]
    start = max(int(active[0] * w - HEAD_KEEP_S * sr2), 0) if active.size else 0
    # 6) tail trim: last 5 ms window above TAIL_DB, keep TAIL_KEEP_S
    env5, w5 = rms_env_db(y, sr2, 0.005)
    tail_db = recipe.get("tail_db", TAIL_DB)
    active5 = np.where(env5 > tail_db)[0]
    end = min(int((active5[-1] + 1) * w5 + TAIL_KEEP_S * sr2), len(y)) if active5.size else len(y)
    y = y[start:end].copy()

    # 7) fades (click-free); fade-out length capped at half the file
    fi = min(int(recipe.get("fade_in", FADE_IN_S) * sr2), len(y) // 2)
    fo = min(int(recipe.get("fade_out", 0.02) * sr2), len(y) // 2)
    if fi > 0:
        y[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 0:
        y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 1.5

    # 8) final peak reference (fades can shave an early transient), then 16-bit
    #    with TPDF dither (deterministic seed → byte-identical rebuilds)
    peak2 = float(np.max(np.abs(y))) if len(y) else 0.0
    y = y * (target / max(peak2, 1e-9))
    rng = np.random.default_rng(0x5F1D)
    lsb = 1.0 / 32768.0
    dither = (rng.random(len(y)) + rng.random(len(y)) - 1.0) * lsb
    y16 = np.clip(np.round((y + dither) * 32767.0), -32768, 32767).astype(np.int16)

    out = out_root / recipe["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(out), y16, sr2, subtype="PCM_16")

    # measurements of the produced file
    yf = y16.astype(np.float64) / 32768.0
    peak_out = float(np.max(np.abs(yf))) if len(yf) else 0.0
    envm, wm = rms_env_db(yf, sr2, 0.005)
    act = envm > -60.0
    rms_active = float(np.sqrt(np.mean((10 ** (envm[act] / 20.0)) ** 2))) if act.any() else 0.0
    env1, w1 = rms_env_db(yf, sr2, 0.001)
    head_ms = 1000.0 * (np.argmax(env1 > -60.0) * w1 / sr2) if (env1 > -60.0).any() else 0.0
    last = np.where(envm > tail_db)[0]
    tail_ms = 1000.0 * ((len(envm) - 1 - last[-1]) * wm / sr2) if last.size else 0.0
    return {
        "out": recipe["out"], "src": recipe["src"], "pack": pack_name, "publisher": publisher,
        "licence": licence, "src_path": folder + recipe["src"], "src_sr": sr, "src_ch": src_channels,
        "src_dur": src_frames / sr, "trim": trim, "hp": recipe.get("hp"), "lp": recipe.get("lp"),
        "fade_in_ms": 1000.0 * recipe.get("fade_in", FADE_IN_S), "fade_out_ms": 1000.0 * recipe.get("fade_out", 0.02),
        "dur": len(yf) / sr2, "peak_dbfs": db(peak_out), "rms_active_dbfs": db(rms_active),
        "head_ms": head_ms, "tail_ms": tail_ms, "clip": int(np.sum(np.abs(y16) >= 32767)),
        "phone_band": band_share(yf, sr2, 250.0, 3000.0), "sub_200": band_share(yf, sr2, 20.0, 200.0),
        "above_4k": band_share(yf, sr2, 4000.0, sr2 / 2), "role": recipe["role"], "owner": recipe["owner"],
        "bytes": out.stat().st_size,
    }


def write_manifest(rows: list[dict], path: Path, source_root: Path) -> None:
    lines = [
        "# PRODUCTION_FILES.md — generated by `tools/audio_production_build.py` (M8.8-02)",
        "",
        "Do not edit by hand; re-run the script when a recipe changes. Every production file",
        "under `assets/audio/sfx/` is listed with its source, licence, processing and measured",
        "result. Source library (owner-local, outside the repo): `%s`." % source_root,
        "",
        "Common processing: down-mix to mono (channel mean) → windowed-sinc resample to 44.1 kHz",
        "(once) → at most one 2nd-order high-pass and one low-pass → peak reference %.0f dBFS →" % PEAK_DBFS,
        "head trim (≤ %.0f ms pre-roll before the first −60 dB window) → tail trim (%.0f dBFS, +%.0f ms)" % (
            HEAD_KEEP_S * 1000, TAIL_DB, TAIL_KEEP_S * 1000),
        "→ fades → final peak %.0f dBFS → 16-bit PCM with TPDF dither. `phone band` = share of spectral" % PEAK_DBFS,
        "power in 250 Hz–3 kHz",
        "(what a phone speaker reproduces); `< 200 Hz` and `> 4 kHz` are the sub and hiss shares.",
        "",
        "## Files",
        "",
        "| production file | source file | pack / library | publisher | licence | trim (s) | HP | LP | fade in/out (ms) | length (s) | peak dBFS | RMS dBFS (active) | head ms | tail ms | clip | phone band | < 200 Hz | > 4 kHz | bytes |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        trim = "%.3f–%.3f" % r["trim"] if r["trim"] else "whole (%.2f)" % r["src_dur"]
        lines.append("| `%s` | `%s` | %s | %s | %s | %s | %s | %s | %.0f / %.0f | %.3f | %.1f | %.1f | %.1f | %.0f | %d | %.0f %% | %.0f %% | %.0f %% | %d |" % (
            r["out"], r["src"], r["pack"], r["publisher"], r["licence"], trim,
            ("%d Hz" % r["hp"]) if r["hp"] else "—", ("%d Hz" % r["lp"]) if r["lp"] else "—",
            r["fade_in_ms"], r["fade_out_ms"], r["dur"], r["peak_dbfs"], r["rms_active_dbfs"], r["head_ms"], r["tail_ms"],
            r["clip"], 100 * r["phone_band"], 100 * r["sub_200"], 100 * r["above_4k"], r["bytes"]))
    lines += ["", "## Roles and owner decisions", "", "| production file | runtime role | owner decision (M8.8-02 brief) |", "|---|---|---|"]
    for r in rows:
        lines.append("| `%s` | %s | %s |" % (r["out"], r["role"], r["owner"]))
    lines += ["", "## Source paths", "", "| production file | source (relative to the library) | source format |", "|---|---|---|"]
    for r in rows:
        lines.append("| `%s` | `%s` | %d Hz, %d ch, %.2f s |" % (r["out"], r["src_path"], r["src_sr"], r["src_ch"], r["src_dur"]))
    total = sum(r["bytes"] for r in rows)
    lines += ["", "Total: %d files, %.1f KB." % (len(rows), total / 1024.0), ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=SOURCE_DEFAULT)
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--manifest", default=MANIFEST_DEFAULT)
    ap.add_argument("--only", default=None, help="substring filter on the output name")
    ap.add_argument("--no-manifest", action="store_true")
    args = ap.parse_args()
    source_root = Path(args.source)
    out_root = Path(args.out)
    rows: list[dict] = []
    for recipe in RECIPES:
        if args.only and args.only not in recipe["out"]:
            continue
        r = build_one(recipe, source_root, out_root)
        rows.append(r)
        flags = []
        if r["head_ms"] > 5.0:
            flags.append("HEAD>5ms")
        if r["clip"]:
            flags.append("CLIP")
        if r["peak_dbfs"] > -3.0 or r["peak_dbfs"] < -6.0:
            flags.append("PEAK")
        print("%-42s %6.3fs  peak %5.1f  rms %6.1f  head %4.1fms  tail %5.0fms  phone %3.0f%%  <200 %3.0f%%  >4k %3.0f%%  %s" % (
            r["out"], r["dur"], r["peak_dbfs"], r["rms_active_dbfs"], r["head_ms"], r["tail_ms"],
            100 * r["phone_band"], 100 * r["sub_200"], 100 * r["above_4k"], " ".join(flags)))
    if not args.no_manifest and not args.only:
        write_manifest(rows, Path(args.manifest), source_root)
        print("manifest -> %s" % args.manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
