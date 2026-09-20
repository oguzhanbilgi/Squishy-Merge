#!/usr/bin/env python
"""audio_source_audit.py — M8.8-01 production audio source inventory.

Indexes every audio file under the OWNER-LOCAL source library
(``D:\\dev\\squishy-audio-source`` by default; NOT part of the repo), reads
container metadata without re-encoding anything, decodes a bounded window
of each file for selection-only features and writes:

    <out>/AUDIO_SOURCE_INVENTORY.csv    one row per file (metadata + features)
    <out>/AUDIO_SOURCE_INVENTORY.json   same rows, machine readable
    <out>/audit_run.json                run summary (counts, packs, errors)

The features are FILTERS, not verdicts: RMS / peak / spectral centroid /
zero-crossing rate / transient strength / low-frequency share / effective
length. No aesthetic decision is made here — see FINAL_AUDIO_PALETTE.md.

Requirements (isolated, outside the game repo):
    D:\\dev\\squishy-audio-source\\.venv  with  numpy + soundfile
    (python -m venv .venv && .venv\\Scripts\\pip install numpy soundfile)

Originals are opened read-only; nothing is written into the source tree.
Runtime / Godot project untouched: this is a Python-only audit tool.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import sys
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

import numpy as np
import soundfile as sf

AUDIO_EXT = {".wav", ".ogg", ".flac", ".mp3"}

# Top-level folder -> pack metadata. The Sonniss vendor folders are resolved
# per-file from the bundle's own Filelist.xlsx (library / supplier / URL).
PACKS = {
    "kenney-impact": {
        "pack": "Kenney Impact Sounds 1.0",
        "publisher": "Kenney (www.kenney.nl)",
        "archive": "kenney_impact-sounds.zip",
        "license_file": "kenney-impact/License.txt",
        "license": "CC0 1.0",
    },
    "kenney-interface": {
        "pack": "Kenney Interface Sounds 1.0",
        "publisher": "Kenney (www.kenney.nl)",
        "archive": "kenney_interface-sounds.zip",
        "license_file": "kenney-interface/License.txt",
        "license": "CC0 1.0",
    },
    "kenney-jingles": {
        "pack": "Kenney Music Jingles",
        "publisher": "Kenney Vleugels (Kenney.nl)",
        "archive": "kenney_music-jingles.zip",
        "license_file": "kenney-jingles/License.txt",
        "license": "CC0 1.0",
    },
    "kenny-ui": {
        "pack": "Kenney UI SFX Set (UI Audio)",
        "publisher": "Kenney Vleugels (Kenney.nl)",
        "archive": "kenney_ui-audio.zip",
        "license_file": "kenny-ui/License.txt",
        "license": "CC0 1.0",
    },
    "sonniss-gdc-2026": {
        "pack": "Sonniss #GameAudioGDC Bundle 2026 (Part 9)",
        "publisher": "Sonniss LTD (per-library suppliers)",
        "archive": "Sonniss.com-GDC2026-GameAudioBundle1of5..5of5.zip",
        "license_file": "sonniss-gdc-2026/License - GDC Game Audio.pdf",
        "license": "Sonniss GDC royalty-free EULA",
    },
}

# Decode at most this many seconds per file for feature analysis. Sonniss
# ambiences run for minutes at 96/192 kHz; the head is enough to classify
# them (they are not SFX candidates anyway).
ANALYSIS_WINDOW_S = 20.0
SILENCE_DB = -60.0
TAIL_DB = -40.0


def db(x: float) -> float:
    return 20.0 * math.log10(max(x, 1e-9))


def load_sonniss_filelist(source: Path) -> dict[str, dict]:
    """FILENAME -> {library, supplier, url} from the bundle's xlsx (stdlib)."""
    out: dict[str, dict] = {}
    root = source / "sonniss-gdc-2026"
    xlsx = next(root.glob("*Filelist.xlsx"), None)
    if xlsx is None:
        return out
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(xlsx) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", ns):
                shared.append("".join(t.text or "" for t in si.iter("{%s}t" % ns["m"])))
        sheet = ET.fromstring(z.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.find("m:sheetData", ns).findall("m:row", ns):
            vals = []
            for c in row.findall("m:c", ns):
                v = c.find("m:v", ns)
                if v is None:
                    vals.append("")
                elif c.get("t") == "s":
                    vals.append(shared[int(v.text)])
                else:
                    vals.append(v.text or "")
            rows.append(vals)
    for r in rows[1:]:
        if len(r) >= 4 and r[0]:
            out[r[0].lower()] = {"library": r[1], "supplier": r[2], "url": r[3]}
    return out


def frame_rms_db(mono: np.ndarray, sr: int, win_ms: float = 5.0) -> tuple[np.ndarray, int]:
    win = max(int(sr * win_ms / 1000.0), 1)
    n = len(mono) // win
    if n == 0:
        return np.array([db(float(np.sqrt(np.mean(mono ** 2))))]), win
    frames = mono[: n * win].reshape(n, win)
    rms = np.sqrt(np.mean(frames ** 2, axis=1))
    return 20.0 * np.log10(np.maximum(rms, 1e-9)), win


def spectral_features(mono: np.ndarray, sr: int) -> dict:
    """Energy-weighted spectral centroid + band shares over the active part."""
    nfft = 4096 if sr > 50000 else 2048
    hop = nfft // 2
    if len(mono) < nfft:
        mono = np.pad(mono, (0, nfft - len(mono)))
    n = 1 + (len(mono) - nfft) // hop
    n = min(n, 4000)  # cap work for long files
    window = np.hanning(nfft).astype(np.float32)
    freqs = np.fft.rfftfreq(nfft, 1.0 / sr)
    psum = np.zeros(len(freqs), dtype=np.float64)
    for i in range(n):
        seg = mono[i * hop : i * hop + nfft] * window
        spec = np.abs(np.fft.rfft(seg)) ** 2
        psum += spec
    total = float(psum.sum()) + 1e-12
    centroid = float((freqs * psum).sum() / total)
    # spectral rolloff 85 %
    cum = np.cumsum(psum) / total
    rolloff = float(freqs[int(np.searchsorted(cum, 0.85))]) if len(freqs) else 0.0

    def share(lo: float, hi: float) -> float:
        m = (freqs >= lo) & (freqs < hi)
        return float(psum[m].sum() / total)

    # tonality: spectral flatness over 100 Hz-10 kHz (0 = pure tone, 1 = noise)
    band = (freqs >= 100) & (freqs <= 10000)
    pb = psum[band] + 1e-18
    flatness = float(np.exp(np.mean(np.log(pb))) / np.mean(pb))
    return {
        "spectral_centroid_hz": round(centroid, 1),
        "spectral_rolloff85_hz": round(rolloff, 1),
        "spectral_flatness": round(flatness, 4),
        "share_sub_80hz": round(share(0, 80), 4),
        "share_low_200hz": round(share(0, 200), 4),
        "share_body_200_800hz": round(share(200, 800), 4),
        "share_mid_800_4k": round(share(800, 4000), 4),
        "share_high_4k_plus": round(share(4000, 22050), 4),
        "share_phone_300_8k": round(share(300, 8000), 4),
    }


def riff_header(path: Path) -> dict:
    """Minimal RIFF/WAVE 'fmt ' + 'data' reader for files libsndfile rejects
    (e.g. a malformed PEAK chunk). Metadata only, no decode."""
    import struct
    with open(path, "rb") as f:
        head = f.read(12)
        if head[:4] != b"RIFF" or head[8:12] != b"WAVE":
            raise ValueError("not RIFF/WAVE")
        fmt = None
        data_size = None
        while True:
            chunk = f.read(8)
            if len(chunk) < 8:
                break
            cid, size = chunk[:4], struct.unpack("<I", chunk[4:])[0]
            if cid == b"fmt ":
                body = f.read(size + (size & 1))
                tag, ch, sr, _, _, bits = struct.unpack("<HHIIHH", body[:16])
                fmt = {"format_tag": tag, "channels": ch, "samplerate": sr, "bits": bits}
            elif cid == b"data":
                data_size = size
                break
            else:
                f.seek(size + (size & 1), 1)
    if fmt is None or data_size is None:
        raise ValueError("fmt/data chunk missing")
    frames = data_size // max(fmt["channels"] * fmt["bits"] // 8, 1)
    return {
        "format": "WAV (riff fallback)",
        "subtype": {1: "PCM", 3: "FLOAT", 65534: "EXTENSIBLE"}.get(fmt["format_tag"], str(fmt["format_tag"])),
        "samplerate": fmt["samplerate"],
        "channels": fmt["channels"],
        "frames": frames,
        "duration_s": round(frames / fmt["samplerate"], 4),
        "bit_depth": fmt["bits"],
    }


def analyse(path: Path, info) -> dict:
    """Bounded decode + selection features. Never writes to `path`."""
    sr = info.samplerate
    frames_to_read = int(min(info.frames, ANALYSIS_WINDOW_S * sr))
    with sf.SoundFile(str(path), "r") as f:
        data = f.read(frames=frames_to_read, dtype="float32", always_2d=True)
    truncated = frames_to_read < info.frames
    if data.shape[0] == 0:
        return {"analysis_error": "empty"}
    peak = float(np.max(np.abs(data)))
    clip_samples = int(np.sum(np.abs(data) >= 0.999))
    mono = data.mean(axis=1)
    stereo_corr = None
    side_ratio = None
    if data.shape[1] >= 2:
        l, r = data[:, 0], data[:, 1]
        denom = float(np.sqrt(np.sum(l ** 2) * np.sum(r ** 2))) + 1e-12
        stereo_corr = float(np.sum(l * r) / denom)
        mid = (l + r) * 0.5
        side = (l - r) * 0.5
        side_ratio = float(np.sum(side ** 2) / (np.sum(mid ** 2) + 1e-12))

    rms_all = float(np.sqrt(np.mean(mono ** 2)))
    env_db, win = frame_rms_db(mono, sr, 5.0)
    peak_env = float(env_db.max())
    active = env_db > SILENCE_DB
    active_frames = mono.reshape(-1)[: (len(env_db) * win)].reshape(len(env_db), win)[active]
    rms_active = float(np.sqrt(np.mean(active_frames ** 2))) if active_frames.size else rms_all

    # leading / trailing silence and effective (tail) duration
    idx_active = np.where(active)[0]
    if idx_active.size:
        lead_s = idx_active[0] * win / sr
        trail_s = (len(env_db) - 1 - idx_active[-1]) * win / sr
    else:
        lead_s = trail_s = 0.0
    above_tail = np.where(env_db > peak_env + TAIL_DB)[0]
    if above_tail.size:
        onset_s = above_tail[0] * win / sr
        tail_end_s = (above_tail[-1] + 1) * win / sr
        effective_s = tail_end_s - onset_s
    else:
        onset_s = 0.0
        effective_s = 0.0

    # transient strength: steepest rise of the 5 ms envelope (dB per 10 ms)
    # and attack time from -20 dB (rel. peak) to peak.
    rise = np.diff(env_db) if len(env_db) > 1 else np.array([0.0])
    rise_db_per_10ms = float(rise.max()) * (10.0 / 5.0)
    peak_i = int(np.argmax(env_db))
    attack_from = peak_i
    while attack_from > 0 and env_db[attack_from] > peak_env - 20.0:
        attack_from -= 1
    attack_ms = (peak_i - attack_from) * win * 1000.0 / sr
    crest_db = db(peak) - db(rms_active)

    # decay: time from peak to -20 dB below peak
    decay_i = peak_i
    while decay_i < len(env_db) - 1 and env_db[decay_i] > peak_env - 20.0:
        decay_i += 1
    decay20_ms = (decay_i - peak_i) * win * 1000.0 / sr

    # zero crossing rate (per second, on active mono)
    sig = mono[int(onset_s * sr) : int((onset_s + max(effective_s, 0.01)) * sr)]
    if sig.size < 2:
        sig = mono
    zcr = float(np.mean(np.abs(np.diff(np.signbit(sig).astype(np.int8)))) * sr)

    # "phone-ish" loudness estimate: remove content below ~100 Hz with a
    # 10 ms moving-average subtraction (vectorised; no scipy on this machine).
    win_hp = max(int(sr / 100.0), 2)
    csum = np.cumsum(np.concatenate(([0.0], mono.astype(np.float64))))
    ma = (csum[win_hp:] - csum[:-win_hp]) / win_hp
    y = mono[win_hp - 1:].astype(np.float64) - ma
    rms_hp = float(np.sqrt(np.mean(y ** 2)))

    feats = {
        "analysis_window_s": round(frames_to_read / sr, 3),
        "analysis_truncated": truncated,
        "peak_dbfs": round(db(peak), 2),
        "clip_samples": clip_samples,
        "rms_dbfs": round(db(rms_all), 2),
        "rms_active_dbfs": round(db(rms_active), 2),
        "rms_hp100_dbfs": round(db(rms_hp), 2),
        "crest_db": round(crest_db, 2),
        "lead_silence_s": round(lead_s, 3),
        "trail_silence_s": round(trail_s, 3),
        "onset_s": round(onset_s, 3),
        "effective_len_s": round(effective_s, 3),
        "attack_ms": round(attack_ms, 1),
        "decay20_ms": round(decay20_ms, 1),
        "transient_db_per_10ms": round(rise_db_per_10ms, 2),
        "zcr_per_s": round(zcr, 1),
        "stereo_corr": None if stereo_corr is None else round(stereo_corr, 3),
        "side_mid_ratio": None if side_ratio is None else round(side_ratio, 4),
    }
    feats.update(spectral_features(mono, sr))
    feats.update(pitch_trajectory(mono, sr, onset_s, effective_s))
    return feats


def pitch_trajectory(mono: np.ndarray, sr: int, onset_s: float, effective_s: float) -> dict:
    """Dominant spectral peak (100 Hz-8 kHz) in the first and last quarter of
    the effective region: a crude 'does it go up or down' flag for whooshes,
    arps and jingles. Not a pitch tracker."""
    a = int(onset_s * sr)
    b = int((onset_s + max(effective_s, 0.02)) * sr)
    seg = mono[a:b]
    if len(seg) < 256:
        return {"f0_start_hz": None, "f0_end_hz": None, "pitch_dir_semitones": None}
    q = max(len(seg) // 4, 256)

    def peak_hz(x: np.ndarray) -> float:
        n = 1 << max(int(np.ceil(np.log2(len(x)))), 8)
        spec = np.abs(np.fft.rfft(x * np.hanning(len(x)), n=n)) ** 2
        fr = np.fft.rfftfreq(n, 1.0 / sr)
        m = (fr >= 100) & (fr <= 8000)
        return float(fr[m][int(np.argmax(spec[m]))]) if m.any() else 0.0

    f0s = peak_hz(seg[:q])
    f0e = peak_hz(seg[-q:])
    semis = 12.0 * math.log2(max(f0e, 1.0) / max(f0s, 1.0))
    return {"f0_start_hz": round(f0s, 1), "f0_end_hz": round(f0e, 1),
            "pitch_dir_semitones": round(semis, 2)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=r"D:\dev\squishy-audio-source")
    ap.add_argument("--out", default="build/qa_m8.8-01")
    ap.add_argument("--limit", type=int, default=0, help="debug: stop after N files")
    args = ap.parse_args()
    source = Path(args.source)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    filelist = load_sonniss_filelist(source)
    rows: list[dict] = []
    errors: list[dict] = []
    t0 = time.time()
    files = sorted(p for p in source.rglob("*") if p.is_file() and p.suffix.lower() in AUDIO_EXT
                   and ".venv" not in p.parts and "extracted" not in p.parts[:1])
    if args.limit:
        files = files[: args.limit]
    print(f"indexing {len(files)} audio files under {source}")
    for i, p in enumerate(files):
        rel = p.relative_to(source)
        top = rel.parts[0]
        pack = PACKS.get(top)
        if pack is None:
            errors.append({"file": str(rel), "error": "unknown pack folder"})
            continue
        row = {
            "id": f"{top}/{rel.relative_to(top).as_posix()}",
            "pack_folder": top,
            "pack": pack["pack"],
            "publisher": pack["publisher"],
            "archive": pack["archive"],
            "license": pack["license"],
            "license_file": pack["license_file"],
            "library": "",
            "supplier": "",
            "library_url": "",
            "rel_path": rel.as_posix(),
            "filename": p.name,
            "ext": p.suffix.lower(),
            "size_bytes": p.stat().st_size,
        }
        if top == "sonniss-gdc-2026":
            meta = filelist.get(p.name.lower())
            if meta:
                row.update({"library": meta["library"], "supplier": meta["supplier"],
                            "library_url": meta["url"]})
            else:
                row["library"] = rel.parts[1] if len(rel.parts) > 2 else ""
                row["supplier"] = row["library"].split(" - ")[0]
        try:
            info = sf.info(str(p))
            row.update({
                "format": info.format,
                "subtype": info.subtype,
                "samplerate": info.samplerate,
                "channels": info.channels,
                "frames": info.frames,
                "duration_s": round(info.frames / info.samplerate, 4),
            })
            bits = {"PCM_16": 16, "PCM_24": 24, "PCM_32": 32, "FLOAT": 32, "DOUBLE": 64,
                    "PCM_S8": 8, "PCM_U8": 8}.get(info.subtype)
            row["bit_depth"] = bits if bits else ("n/a (lossy)" if info.subtype.upper().startswith(("VORBIS", "MPEG")) else "")
            row.update(analyse(p, info))
        except Exception as exc:  # noqa: BLE001 — record and continue
            row["analysis_error"] = f"{type(exc).__name__}: {exc}"
            errors.append({"file": str(rel), "error": row["analysis_error"]})
            if p.suffix.lower() == ".wav":
                try:
                    row.update(riff_header(p))
                    row["analysis_error"] += " (metadata via RIFF fallback, no features)"
                except Exception as exc2:  # noqa: BLE001
                    row["analysis_error"] += f"; riff fallback failed: {exc2}"
        rows.append(row)
        if (i + 1) % 50 == 0:
            print(f"  {i + 1}/{len(files)}  {time.time() - t0:.0f}s")

    keys: list[str] = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(out / "AUDIO_SOURCE_INVENTORY.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    with open(out / "AUDIO_SOURCE_INVENTORY.json", "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=1, ensure_ascii=False)

    per_pack: dict[str, dict] = {}
    for r in rows:
        d = per_pack.setdefault(r["pack"], {"files": 0, "bytes": 0, "duration_s": 0.0,
                                            "libraries": set()})
        d["files"] += 1
        d["bytes"] += r["size_bytes"]
        d["duration_s"] += float(r.get("duration_s") or 0.0)
        if r.get("library"):
            d["libraries"].add(r["library"])
    for d in per_pack.values():
        d["libraries"] = sorted(d["libraries"])
        d["duration_s"] = round(d["duration_s"], 1)
    summary = {
        "source": str(source),
        "files_indexed": len(rows),
        "errors": errors,
        "analysis_window_s": ANALYSIS_WINDOW_S,
        "elapsed_s": round(time.time() - t0, 1),
        "per_pack": per_pack,
    }
    with open(out / "audit_run.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=1, ensure_ascii=False)
    print(json.dumps({k: v for k, v in summary.items() if k != "per_pack"}, indent=1))
    for k, v in per_pack.items():
        print(f"  {k}: {v['files']} files, {v['bytes'] / 1e6:.1f} MB, {v['duration_s'] / 60:.1f} min")
    return 0


if __name__ == "__main__":
    sys.exit(main())
