#!/usr/bin/env python
"""M8.6-10 Devam (revive) asset turetmesi.

Owner'in kanatli-kalp tepeliginden (`panel_candy_crown.png`) ORTADAKI kalbi
tek basina ayirir: `icon_heart_revive.png`. Yeni sanat DEGIL — ayni cizim,
ayni golgelendirme, ayni altin cerceve; yalnizca kanatlar, tac ve iki kucuk
yildiz maskelenir (M8.6-09'daki `make_result_art.py` ile ayni gerekce: owner
ciziminden runtime'in ihtiyac duydugu turev, elle boyanmis yeni bir ikon
degil).

    python tools/make_revive_art.py

Kaynak dosyaya DOKUNULMAZ; oyun (`ReviveOffer`) yalnizca ciktiyi okur: devam
hakki sayacindaki iki kalp (kalan = renkli, kullanilmis = soluk) ve
kahraman kalp.

Yontem: altin cerceve dis kenari kalp merkezinden isinsal olarak izlenir
(pembe govde -> altin cerceve -> disari); kanat temasi olan yan sektorlerde
cerceve kalinligi ile sinirlanir, yildiz sektorlerinde komsu acilar arasinda
yumusak gecisle, tac sektorunde olculen yarik yaricapiyla V ucuyla doldurulur.
"""
from __future__ import annotations

import math
import os
import sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover
    sys.exit("pillow gerekli:  python -m pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "visual", "ui")

# Tepelik icindeki kalp bolgesi (1024x328 kaynakta) ve kalp merkezi (kirpim icinde).
CROP = (340, 40, 684, 328)
CENTER = (172, 148)
# Maskelenen komsular (kirpim icinde): sol/sag yildiz merkezleri, tac.
STAR_LEFT = (44, 232)
STAR_RIGHT = (300, 232)
CROWN = (172, 20)
STAR_SECTOR = 22.0
CROWN_SECTOR = 20.0
# Kanatlarin cerceveye degdigi yan sektorler: cerceve kalinligi ile sinirla.
SIDE_SECTORS = ((150, 210), (330, 360), (0, 30))


def _angle(p: tuple[int, int]) -> float:
    return (math.degrees(math.atan2(p[1] - CENTER[1], p[0] - CENTER[0])) + 360.0) % 360.0


def _in_sector(a: float, lo: float, hi: float) -> bool:
    lo %= 360.0
    hi %= 360.0
    if lo <= hi:
        return lo <= a <= hi
    return a >= lo or a <= hi


def main() -> None:
    src = Image.open(os.path.join(UI, "panel_candy_crown.png")).convert("RGBA")
    crop = src.crop(CROP)
    width, height = crop.size
    px = crop.load()

    def gold(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return a > 200 and r > 160 and g > 80 and b < 130 and r - b > 70 and r - g > 20

    def body(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        pink = a > 200 and r > 200 and b > 120 and r - g > 40
        white = a > 200 and r > 225 and g > 215 and b > 215
        return pink or white

    bad = [
        (_angle(STAR_LEFT) - STAR_SECTOR, _angle(STAR_LEFT) + STAR_SECTOR),
        (_angle(STAR_RIGHT) - STAR_SECTOR, _angle(STAR_RIGHT) + STAR_SECTOR),
        (_angle(CROWN) - CROWN_SECTOR, _angle(CROWN) + CROWN_SECTOR),
    ]
    n = 360
    first_gold = [None] * n
    last_gold = [None] * n
    for i in range(n):
        th = math.radians(i)
        r = 0.0
        seen_body = False
        while r < 200.0:
            x = int(round(CENTER[0] + math.cos(th) * r))
            y = int(round(CENTER[1] + math.sin(th) * r))
            if x < 0 or y < 0 or x >= width or y >= height:
                break
            if body(x, y) and first_gold[i] is None:
                seen_body = True
            elif gold(x, y) and seen_body:
                if first_gold[i] is None:
                    first_gold[i] = r
                last_gold[i] = r
            elif first_gold[i] is not None and r - last_gold[i] > 4.0:
                break
            r += 0.5
    clean = sorted(last_gold[i] - first_gold[i] for i in range(60, 121)
                   if first_gold[i] is not None and last_gold[i] is not None)
    thickness = clean[len(clean) // 2]

    radii: list[float | None] = [None] * n
    for i in range(n):
        if first_gold[i] is None or any(_in_sector(i, lo, hi) for lo, hi in bad):
            continue
        side = any(_in_sector(i, lo, hi) for lo, hi in SIDE_SECTORS)
        capped = first_gold[i] + thickness + 1.0
        radii[i] = min(last_gold[i], capped) if side else last_gold[i]

    cleft = min(first_gold[i] + thickness + 1.0 for i in range(268, 273) if first_gold[i] is not None)
    known = [i for i in range(n) if radii[i] is not None]
    crown_lo = int(_angle(CROWN) - CROWN_SECTOR)
    crown_hi = int(_angle(CROWN) + CROWN_SECTOR)
    for i in range(n):
        if radii[i] is not None:
            continue
        prev = max([k for k in known if k < i], default=max(known) - n)
        nxt = min([k for k in known if k > i], default=min(known) + n)
        rp = radii[prev % n]
        rn = radii[nxt % n]
        if crown_lo <= i <= crown_hi:
            c = 270
            if i <= c:
                t = (i - prev) / (c - prev)
                radii[i] = rp + (cleft - rp) * t
            else:
                t = (i - c) / (nxt - c)
                radii[i] = cleft + (rn - cleft) * t
        else:
            t = (i - prev) / (nxt - prev)
            t = t * t * (3.0 - 2.0 * t)
            radii[i] = rp + (rn - rp) * t
    smooth = [radii[i] if crown_lo - 2 <= i <= crown_hi + 2
              else sum(radii[(i + k) % n] for k in range(-2, 3)) / 5.0 for i in range(n)]
    points = [(CENTER[0] + math.cos(math.radians(i)) * (smooth[i] + 1.0),
               CENTER[1] + math.sin(math.radians(i)) * (smooth[i] + 1.0)) for i in range(n)]
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))
    out = crop.copy()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    out = out.crop(out.getchannel("A").getbbox())
    path = os.path.join(UI, "icon_heart_revive.png")
    out.save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT):40s} {out.width}x{out.height}")


if __name__ == "__main__":
    main()
