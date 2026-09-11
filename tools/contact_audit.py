#!/usr/bin/env python
"""M8.5-11 dumpling temas geometrisi denetimi.

Sekiz tier sprite'inin alfa siluetini, collider dairesini (TierConfig.radius)
ve runtime olcegini karsilastirir; "fizik temas ediyor ama sprite'lar
etmiyor" gorsel bosluğunu PIKSEL cinsinden olcer.

    python tools/contact_audit.py            # mevcut (M8.5-10) formul
    python tools/contact_audit.py --fit      # onerilen kalibrasyonla

Gereken: pillow, numpy.

Olcumler (tier basina):
  - texture boyutu, alfa > 0 / 16 / 64 bounding box'lari
  - govde silueti: satir/sutun genisligine dayali, aksesuar (yaprak, tac,
    parilti) HARIC — bkz. body_extents()
  - gorunur agirlik merkezi
  - collider yaricapi, runtime sprite olcegi
  - dunya uzayinda: yan yana temas boslugu (A), taban boslugu (B),
    duvar boslugu (C)

Isaret: pozitif = gorunur bosluk, negatif = gorunur overlap.
"""
from __future__ import annotations

import math
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIER_CONFIG = os.path.join(ROOT, "scripts", "game", "tier_config.gd")
TEXTURE = os.path.join(ROOT, "assets", "visual", "dumpling_tier%d.png")

# Govde silueti icin: bir satir/sutun, en genis satirin/sutunun bu oraninin
# altinda kaliyorsa "aksesuar" sayilir (yaprak, tac ucu, parilti, golge).
BODY_ROW_RATIO = 0.42


def read_radii() -> list[float]:
    text = open(TIER_CONFIG, encoding="utf-8").read()
    return [float(m) for m in re.findall(r'"radius":\s*([0-9.]+)', text)]


def bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    rows = np.where(mask.any(axis=1))[0]
    cols = np.where(mask.any(axis=0))[0]
    if rows.size == 0:
        return None
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def body_extents(alpha: np.ndarray, threshold: int = 64) -> tuple[int, int, int, int]:
    """Aksesuarsiz govde: alfa > threshold maskesinde satir genisligi en genis
    satirin BODY_ROW_RATIO'sunun altina dusen ust/alt seritler ve sutun
    yuksekligi en yuksek sutunun ayni oraninin altina dusen sol/sag seritler
    atiliyor. Tepedeki yaprak/tac ve alttaki ince golge boyle eleniyor."""
    mask = alpha > threshold
    row_w = mask.sum(axis=1)
    col_h = mask.sum(axis=0)
    row_ok = row_w >= row_w.max() * BODY_ROW_RATIO
    col_ok = col_h >= col_h.max() * BODY_ROW_RATIO
    rows = np.where(row_ok)[0]
    cols = np.where(col_ok)[0]
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def measure(tier: int, fit: bool) -> dict:
    im = Image.open(TEXTURE % tier).convert("RGBA")
    a = np.asarray(im)[:, :, 3].astype(np.int32)
    w, h = im.size
    body = body_extents(a)
    ys, xs = np.nonzero(a > 64)
    wsum = a[a > 64].astype(np.float64)
    r = read_radii()[tier - 1]
    if fit:
        sx, sy, off = fit_scale(body, w, h, r)
    else:
        sx = sy = r * 2.0 / math.sqrt(w * h)
        off = (0.0, 0.0)
    # Sprite merkezi (dunya, collider merkezine gore) = off. Govde kenarlari:
    left = off[0] + (body[0] - w / 2.0) * sx
    right = off[0] + (body[2] - w / 2.0) * sx
    top = off[1] + (body[1] - h / 2.0) * sy
    bottom = off[1] + (body[3] - h / 2.0) * sy
    return {
        "tier": tier, "w": w, "h": h, "r": r, "sx": sx, "sy": sy, "off": off,
        "bb0": bbox(a > 0), "bb16": bbox(a > 16), "bb64": bbox(a > 64), "body": body,
        "cx": float((xs * wsum).sum() / wsum.sum()), "cy": float((ys * wsum).sum() / wsum.sum()),
        "vis_w": right - left, "vis_h": bottom - top,
        "gap_ab": 2.0 * r - (right - left),      # iki ayni tier, merkezler 2r
        "gap_floor": r - bottom,                  # collider tabanda
        "gap_wall": r - right,                    # collider duvarda
        "gap_top": r + top,                       # ustune oturan parcaya bosluk (tek taraf)
        "stretch": sy / sx,
    }


def audit(fit: bool) -> None:
    print("mode:", "FIT (onerilen kalibrasyon)" if fit else "CURRENT (geometrik ortalama)")
    print()
    print("tier  tex      bb>0            bb>16           bb>64           body(no-acc)     "
          "centroid       r    sx      sy      vis_w  vis_h  gapAB  floorB  wallC  topGap")
    for tier in range(1, 9):
        m = measure(tier, fit)
        print("%d   %4dx%-4d %-15s %-15s %-15s %-16s (%5.1f,%5.1f) %5.1f %7.4f %7.4f %6.1f %6.1f %6.1f %7.1f %6.1f %6.1f" % (
            m["tier"], m["w"], m["h"], str(m["bb0"]), str(m["bb16"]), str(m["bb64"]), str(m["body"]),
            m["cx"], m["cy"], m["r"], m["sx"], m["sy"], m["vis_w"], m["vis_h"],
            m["gap_ab"], m["gap_floor"], m["gap_wall"], m["gap_top"]))
    print()
    print("gapAB  : iki ayni tier collider tam temasta gorunur govdeler arasi bosluk (px, + bosluk / - overlap)")
    print("floorB : collider tabana degerken gorunur alt piksel ile taban arasi (px)")
    print("wallC  : collider duvara degerken gorunur sag piksel ile duvar arasi (px)")
    print("topGap : collider ust kenari ile gorunur govde ustu arasi (ustune oturan parcanin gorunur boslugunun yarisi)")
    if fit:
        print()
        print("GDScript tablosu (DumplingVisual.CONTACT_FIT), sira = tier 1..8:")
        for tier in range(1, 9):
            m = measure(tier, True)
            print("	{\"scale\": Vector2(%.5f, %.5f), \"offset\": Vector2(%.2f, %.2f)},  # tier %d, stretch %.2f" % (
                m["sx"], m["sy"], m["off"][0], m["off"][1], tier, m["stretch"]))


def fit_scale(body, w, h, r) -> tuple[float, float, tuple[float, float]]:
    """Onerilen kalibrasyon (collider DEGISMIYOR):

    sx : govde genisligi = 2r + CONTACT_OVERLAP  (yan yana hafif overlap)
    sy : govde yuksekligi 2r * HEIGHT_FILL'e yaklassin, ama sanat en fazla
         MAX_STRETCH kadar dikey uzasin (daha fazlasi karakteri bozar) ve
         asla sx'in altina inmesin
    off: govde merkezi yatayda collider merkezine, govde alt kenari
         collider alt kenarinin FLOOR_INSET ustune (dunya px)
    """
    body_w = body[2] - body[0]
    body_h = body[3] - body[1]
    sx = (2.0 * r + CONTACT_OVERLAP) / body_w
    sy_target = (2.0 * r * HEIGHT_FILL) / body_h
    sy = max(sx, min(sx * MAX_STRETCH, sy_target))
    body_cx = (body[0] + body[2]) / 2.0
    off_x = (w / 2.0 - body_cx) * sx
    off_y = (r - FLOOR_INSET) - (body[3] - h / 2.0) * sy
    return sx, sy, (off_x, off_y)


# Yan yana temasta istenen hafif overlap (px, dunya) — yumusak dumpling hissi.
CONTACT_OVERLAP = 2.0
# Govde alt kenari taban colliderinin bu kadar ustunde kalsin (px).
FLOOR_INSET = 1.0
# Govde yuksekliginin collider capina orani hedefi ve izin verilen en buyuk
# dikey uzama (sy / sx). Sprite'lar ~1.3-1.4 en/boy oraninda genis bloblar;
# 1.0'a (daire) cekmek karakteri bozar, 1.25 "biraz daha tombul" okunuyor.
HEIGHT_FILL = 0.90
MAX_STRETCH = 1.25


if __name__ == "__main__":
    audit("--fit" in sys.argv)
