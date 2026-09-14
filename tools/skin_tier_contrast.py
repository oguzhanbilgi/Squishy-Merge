"""Tier okunurluk sayisal kontrolu (M8.5-17).

    python tools/skin_tier_contrast.py <skin_gallery cikti klasoru>

skin_gallery.gd'nin yazdigi skin_gallery_tiers_a/b.png + skin_gallery_tiers_
layout.json'u okur; her hucrede yuzu ve tepe aksesuarini disarida birakan
uc govde yamasinin (sol / sag kenar + alt kusak) ortalama rengini CIE Lab'a
cevirir ve tier ciftleri arasindaki dE76'yi yazar.

Rapor: her skin icin komsu tier'lar arasi en kucuk dE ve farkli ton
ailesindeki TUM ciftler arasi en kucuk dE (hangi cift). Ayni ton ailesindeki
tier ciftleri (1/6, 2/7, 4/8) tasarim geregi ayni renktir (siluet + boyut +
aksesuar ayirir; varsayilanda dE ~2) — bunlar sayilmaz. Esik: dE < 12 =
"birbirine benziyor" uyarisi (yalniz uyari; nihai karar gorsel). Cikis kodu
1 = en az bir skin uyari aldi.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

WARN = 12.0
# Tasarim geregi ayni govde rengini paylasan tier ciftleri.
SAME_FAMILY = {(1, 6), (2, 7), (4, 8)}
# Yama merkezleri (yaricap katlari): sol/sag govde kenari ve agiz altindaki
# alt kusak. Gozler/agiz merkezde, yanaklar ~+-0.4r, aksesuarlar tepede.
PATCHES = [(-0.62, 0.05), (0.62, 0.05), (0.0, 0.58)]
PATCH_R = 0.16


def srgb_to_lab(rgb):
    c = np.asarray(rgb, dtype=np.float64)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def cell_color(img, cx, cy, r):
    samples = []
    for ox, oy in PATCHES:
        px, py = cx + ox * r, cy + oy * r
        rr = max(2.0, r * PATCH_R)
        x0, x1 = int(px - rr), int(px + rr) + 1
        y0, y1 = int(py - rr), int(py + rr) + 1
        patch = img[y0:y1, x0:x1, :3]
        yy, xx = np.mgrid[y0:y1, x0:x1]
        disk = (xx - px) ** 2 + (yy - py) ** 2 <= rr * rr
        samples.append(patch[disk].mean(0))
    return np.mean(samples, axis=0) / 255.0


def main(out_dir):
    layout = json.load(open(os.path.join(out_dir, "skin_gallery_tiers_layout.json"), encoding="utf-8"))
    baseline = None
    report = []
    for file_name, page in layout.items():
        img = np.asarray(Image.open(os.path.join(out_dir, file_name)).convert("RGB")).astype(np.float64)
        for row in page["rows"]:
            labs = [srgb_to_lab(cell_color(img, c["x"], c["y"], c["r"])) for c in row["cells"]]
            n = len(labs)
            pairs = {}
            for i in range(n):
                for j in range(i + 1, n):
                    pairs[(i + 1, j + 1)] = float(np.linalg.norm(labs[i] - labs[j]))
            adj_pair = min(((t, t + 1) for t in range(1, n)), key=pairs.get)
            cross = {k: v for k, v in pairs.items() if k not in SAME_FAMILY}
            worst = min(cross, key=cross.get)
            name = row["skin"] or "varsayilan"
            if not row["skin"]:
                baseline = pairs
            report.append((name, adj_pair, pairs[adj_pair], worst, pairs[worst]))
    print("%-14s %7s %7s   %7s %7s   %s" % ("skin", "komsu", "dE", "enYakin", "dE", "not"))
    bad = 0
    for name, adj_pair, adj_de, worst, de in report:
        note = ""
        if baseline is not None:
            note = "(varsayilanda %.1f / %.1f)" % (baseline[adj_pair], baseline[worst])
        flag = ""
        if min(adj_de, de) < WARN:
            flag = "  <-- BENZER"
            if name != "varsayilan":
                bad += 1
        print("%-14s %7s %7.1f   %7s %7.1f   %s%s" % (
            name, "T%d-T%d" % adj_pair, adj_de, "T%d-T%d" % worst, de, note, flag))
    print("\nesik dE < %.0f (ayni aile 1/6, 2/7, 4/8 haric); uyari alan skin: %d" % (WARN, bad))
    return bad


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1]) == 0 else 1)
