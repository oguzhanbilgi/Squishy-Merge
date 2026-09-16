#!/usr/bin/env python
"""M8.6-03B Home hub asset turetmesi.

Owner'in `_visual_source/chatgpt_ui/` arsivinden Ana Sayfa hero'su icin
PRODUCTION dosyasi uretir. Kaynak arsivi runtime'a baglanmaz; oyun yalnizca
`assets/visual/ui/` altindaki ciktiyi okur (make_gameplay_art.py ile ayni
kural).

    python tools/make_home_art.py

Neden ayri bir dosya: `tutorial_pose.png` (350x293) level 1 ipucu icin
~180 px'e gore kucultulmustu. Home hero'sunda maskot 720 tuvalinde 400-480
px, 1080 px cihazda 1.5x -> ~700 px fiziksel; o dosya 2x buyutulup
bulaniklasiyordu (M8.6-03 cekimlerinde gorunuyor). Ayni kaynak burada hero
olcusune gore (genislik 800, 1.5x cihazda ~1:1) yeniden turetiliyor.
Ipucu dosyasina DOKUNULMUYOR.
"""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("pillow gerekli:  python -m pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_visual_source", "chatgpt_ui")
UI = os.path.join(ROOT, "assets", "visual", "ui")

# Hero maskotu: tuvalde en fazla ~480 px yukseklik, cihazda 1.5x.
HERO_WIDTH = 800


def trim(im: Image.Image) -> Image.Image:
    return im.crop(im.getchannel("A").getbbox())


def fit_w(im: Image.Image, width: int) -> Image.Image:
    k = width / im.width
    return im.resize((width, max(1, round(im.height * k))), Image.LANCZOS)


def save(im: Image.Image, path: str) -> None:
    im.save(path, optimize=True)
    print(f"{os.path.relpath(path, ROOT):40s} {im.width}x{im.height}")


def main() -> None:
    src = Image.open(os.path.join(SRC, "tutorial_pose.png")).convert("RGBA")
    hero = fit_w(trim(src), HERO_WIDTH)
    save(hero, os.path.join(UI, "hero_mascot.png"))


if __name__ == "__main__":
    main()
