"""Gameplay skin govde maskeleri (M8.5-14).

8 tier sprite'inin (assets/visual/dumpling_tier1..8.png) HAMUR GOVDESINI
isaretleyen 8 gri maske uretir:

    assets/visual/skins/generated/body_mask_tier{1..8}.png

Beyaz = govde (skin shader'i burayi yeniden renklendirir/desenler),
siyah = korunur (goz, agiz, yanak, kontur, yaprak/fiyonk/yildiz/tac).
Alfa kanali yok; maske tier dokusuyla AYNI boyutta, ayni UV ile ornekleniyor.

Yontem (dokuya gore parametrik, elle 160 asset yok):
  1. opak piksel (alfa > 0.5)
  2. renk tonu govdenin baskin tonuna yakin (tier basina merkez + tolerans)
  3. koyu pikseller (kontur, goz, agiz) disarida: V < DARK_V
  4. ayni tondaki aksesuarlar / yanaklar icin elle DISLAMA elipsleri
     (normalize doku koordinati; tier 2 ve 7'de yanak da gövdeyle ayni ton,
     tier 6'da yildiz, tier 7'de fiyonk, tier 8'de tac)
  5. kucuk delikler kapatilir, kenar 1 px yumusatilir

Kalibrasyon: `python tools/make_skin_masks.py --debug <klasor>` her tier icin
maske ust uste bindirilmis kontrol karesi yazar (kirmizi = korunan alan).
Dokular degisirse yeniden calistir; cikti maskeler repoda takip ediliyor.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

SRC = "assets/visual/dumpling_tier{}.png"
OUT_DIR = "assets/visual/skins/generated"
OUT = os.path.join(OUT_DIR, "body_mask_tier{}.png")

DARK_V = 0.40          # bunun altindaki V kontur/goz/agiz sayilir
# tier -> (govde ton merkezi (derece), tolerans, dislama elipsleri [(cx,cy,rx,ry)])
# Elipsler normalize doku koordinati (0..1). Yanak/aksesuar konumlari
# --debug ciktisiyla elle kalibre edildi.
CONFIG = {
    1: dict(hue=45, tol=28, exclude=[]),
    2: dict(hue=333, tol=22, exclude=[(0.30, 0.66, 0.11, 0.09), (0.70, 0.66, 0.11, 0.09)]),
    3: dict(hue=140, tol=36, exclude=[], leaf_sat=0.62),
    4: dict(hue=200, tol=42, exclude=[]),
    5: dict(hue=262, tol=30, exclude=[]),
    6: dict(hue=47, tol=25, exclude=[(0.79, 0.30, 0.13, 0.15)]),
    7: dict(hue=330, tol=22, exclude=[(0.29, 0.63, 0.10, 0.08), (0.70, 0.63, 0.10, 0.08),
                                      (0.76, 0.24, 0.20, 0.18)]),
    8: dict(hue=203, tol=42, exclude=[]),
}


def hue_dist(h, c):
    d = np.abs(h - c) % 360.0
    return np.minimum(d, 360.0 - d)


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    delta = mx - mn
    h = np.zeros_like(mx)
    nz = delta > 1e-6
    rc = np.where(nz, (mx - r) / np.where(nz, delta, 1), 0)
    gc = np.where(nz, (mx - g) / np.where(nz, delta, 1), 0)
    bc = np.where(nz, (mx - b) / np.where(nz, delta, 1), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0
    h = np.where(nz, h, 0)
    s = np.where(mx > 1e-6, delta / np.where(mx > 1e-6, mx, 1), 0)
    return h * 360.0, s, mx


def build_mask(tier):
    cfg = CONFIG[tier]
    img = Image.open(SRC.format(tier)).convert("RGBA")
    a = np.asarray(img).astype(np.float32) / 255.0
    h, s, v = rgb_to_hsv(a[..., :3])
    opaque = a[..., 3] > 0.5
    body = opaque & (hue_dist(h, cfg["hue"]) <= cfg["tol"]) & (v >= DARK_V)
    # Beyaz parlamalar: ton belirsiz ama govdenin parcasi (dusuk doygunluk,
    # cok acik). Yalniz govde ile cevrili olduklari icin kapatma adiminda
    # da dolarlar; burada dogrudan ekleniyor.
    body |= opaque & (s < 0.12) & (v > 0.85)
    if "leaf_sat" in cfg:
        body &= ~(opaque & (s >= cfg["leaf_sat"]) & (hue_dist(h, 115) < 30))
    hgt, wid = body.shape
    yy, xx = np.mgrid[0:hgt, 0:wid]
    for cx, cy, rx, ry in cfg["exclude"]:
        ell = ((xx / wid - cx) / rx) ** 2 + ((yy / hgt - cy) / ry) ** 2 <= 1.0
        body &= ~ell
    m = Image.fromarray((body * 255).astype(np.uint8), "L")
    # Kucuk delikleri kapat (agiz cevresi kirintilari), sonra 1 px yumusat.
    m = m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    m = m.filter(ImageFilter.GaussianBlur(0.6))
    return img, m


def debug_frame(img, mask):
    rgb = np.asarray(img).astype(np.float32)
    m = np.asarray(mask).astype(np.float32)[..., None] / 255.0
    keep = (rgb[..., 3:4] > 64) * (1.0 - m)
    out = rgb[..., :3] * (1 - 0.65 * keep) + np.array([255, 0, 0]) * 0.65 * keep
    frame = Image.fromarray(out.astype(np.uint8), "RGB")
    return frame


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    debug_dir = None
    if "--debug" in sys.argv:
        debug_dir = sys.argv[sys.argv.index("--debug") + 1]
        os.makedirs(debug_dir, exist_ok=True)
    for tier in range(1, 9):
        img, mask = build_mask(tier)
        mask.save(OUT.format(tier), optimize=True)
        cov = np.asarray(mask).mean() / 255.0
        print("tier %d: %dx%d  govde orani %.0f%%" % (tier, mask.width, mask.height, cov * 100))
        if debug_dir:
            debug_frame(img, mask).save(os.path.join(debug_dir, "mask_tier%d.png" % tier))


if __name__ == "__main__":
    main()
