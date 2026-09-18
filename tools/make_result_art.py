#!/usr/bin/env python
"""M8.6-09 Round sonu asset turetmesi.

Owner'in `icon_star_empty.png`'sinden (altin kontur yildiz) yeniden boyanabilir
bir "yumusak bos yildiz" turetir: `icon_star_empty_soft.png`. Yeni sanat
DEGIL — ayni cizim, ayni golgelendirme; yalnizca renk kanali beyaza
normalize edilir ki runtime `self_modulate` ile lavanta/krem boyayabilsin
(modulate yalnizca koyultur: altin konturu lavantaya cevirmenin baska yolu yok,
`make_ui_core.py`'nin LayerLab renkli parcalari beyaza indirgemesiyle ayni
gerekce).

    python tools/make_result_art.py

Kaynak dosyaya DOKUNULMAZ; oyun (`ResultStarStrip`) yalnizca ciktiyi okur.
Kazanilan yildiz owner'in dolu altin yildizi olarak kalir.
"""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("pillow gerekli:  python -m pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "visual", "ui")

# Parlaklik araligi: en koyu kontur pikseli -> LOW, en parlak -> 1.0.
# LOW 0.58: golgelendirme okunur kalir ama lavanta boya koyu mora donmez.
LOW = 0.58


def main() -> None:
    src = Image.open(os.path.join(UI, "icon_star_empty.png")).convert("RGBA")
    px = src.load()
    lum = []
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a > 8:
                lum.append(0.299 * r + 0.587 * g + 0.114 * b)
    lo, hi = min(lum), max(lum)
    span = max(1.0, hi - lo)
    out = Image.new("RGBA", src.size)
    dst = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a <= 8:
                dst[x, y] = (255, 255, 255, 0)
                continue
            t = (0.299 * r + 0.587 * g + 0.114 * b - lo) / span
            v = int(round(255 * (LOW + (1.0 - LOW) * t)))
            dst[x, y] = (v, v, v, a)
    path = os.path.join(UI, "icon_star_empty_soft.png")
    out.save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT):40s} {out.width}x{out.height}")


if __name__ == "__main__":
    main()
