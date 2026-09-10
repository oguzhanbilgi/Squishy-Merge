#!/usr/bin/env python
"""M8.5-08 oyun ekrani asset turetmesi.

Owner'in `_visual_source/chatgpt_ui/` altindaki ChatGPT kaynaklarindan
`assets/visual/` altindaki PRODUCTION dosyalarini uretir. Kaynak arsivi
runtime'a HIC baglanmiyor; oyun yalnizca buradan cikan dosyalari okuyor.

    python tools/make_gameplay_art.py

Gereken: pillow, numpy.

Neden GDScript degil: mevcut `tools/make_owner_sprites.gd` duz kirp/olcekle
isleri yapiyor. Buradaki iki is onun yapamayacagi turden:

1. Dikey bambu duvarin SAHTE seffafligi. `board_wall_bamboo_vertical.png`
   %100 OPAK: satranc deseni gercek piksel olarak goruntuye basilmis. Alfa
   kanali kontrol edilerek dogrulandi. Desene ve yaprak susune degmeyen
   temiz sutun araligi olculerek kesiliyor (bkz. WALL_CROP).

2. Buton pill'lerini ortak orana getirmek. Uc durumun kaynak orani farkli
   (normal 2.45 / secili 2.30 / pasif 3.01); duz gerilseler uclardaki
   yildiz susleri durum degistikce sekil degistirirdi. Surekli bir sutun
   haritasiyla olcek yildiz kapaklarinda tam 1:1 kaliyor, farkin tamami
   pill'in duz orta seridinde soguruluyor (bkz. set_aspect).
"""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:  # pragma: no cover
    sys.exit("pillow ve numpy gerekli:  python -m pip install pillow numpy")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_visual_source", "chatgpt_ui")
UI = os.path.join(ROOT, "assets", "visual", "ui")
FX = os.path.join(ROOT, "assets", "visual", "fx")

# --- Buton turetmesi ------------------------------------------------------
# Guc cubugu butonu 172x86 (2.00), pencere CTA'si 496x96 (5.17). Ikisi de
# kaynak pill'lerin dogal oranina yakin secildi.
POWER_SIZE = (480, 240)
CTA_SIZE = (620, 120)
# Yildiz suslerinin olculmus dis orani: mavi 0.13-0.19, gri 0.10.
# 0.26 hepsini guvenle iceriyor.
CAP = 0.26
# Kapak/orta gecisinin yari genisligi (kapak oraninin kati).
RAMP = 0.20
# Pill GOVDESI icin alfa esigi. Duz alfa-bbox yanlis sonuc veriyor: dis
# parilti govdeden cok genis ve neredeyse seffaf, bbox onu da alinca govde
# butonun ancak yarisini dolduruyor.
BODY_ALPHA = 150
GLOW_PAD = 0.07

# Buton durum sheet'indeki olculmus bos sutun araliklari.
BTN_NORMAL_CROP = (50, 0, 995, 682)
BTN_SELECTED_CROP = (1023, 0, 2032, 682)

# --- Sheet kesitleri (hepsi olculmus BOS sutun/satir bantlarindan) --------
# power_icons_bomb_upgrade_shake_sheet.png: bos sutunlar 642-757, 1311-1408.
SHAKE_CROP = (1408, 18, 2030, 645)
# power_fx_bomb_impact_upgrade_sheet.png: bos sutunlar 686-744, 1367-1448.
BOMB_IMPACT_CROP = (744, 38, 1367, 638)
UPGRADE_BEAM_CROP = (1448, 38, 2007, 638)
# board_wall_bamboo_vertical.png: satranc deseni x<350 ve x>677'de; yaprak
# susleri x 60-119 ve 220-271 arasinda (kesit koordinatlarinda). Geriye
# temiz VE yapraksiz tek bir krem bambu sutunu kaliyor.
WALL_CROP = (469, 0, 560, 1536)


def load(name: str) -> Image.Image:
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def trim(im: Image.Image) -> Image.Image:
    return im.crop(im.getchannel("A").getbbox())


def square(im: Image.Image, size: int) -> Image.Image:
    """Kirp, kutuya sigdir, saydam bir kareye ortala."""
    im = trim(im)
    w, h = im.size
    s = min((size - 8) / w, (size - 8) / h)
    im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, ((size - im.size[0]) // 2, (size - im.size[1]) // 2))
    return out


def fit_w(im: Image.Image, width: int) -> Image.Image:
    im = trim(im)
    w, h = im.size
    return im.resize((width, max(1, round(h * width / w))), Image.LANCZOS)


def body_crop(im: Image.Image) -> Image.Image:
    """Pill govdesine kirp, olculu bir parilti payi birak."""
    mask = im.getchannel("A").point(lambda v: 255 if v >= BODY_ALPHA else 0)
    bb = mask.getbbox()
    pad = round((bb[3] - bb[1]) * GLOW_PAD)
    w, h = im.size
    return im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad),
                    min(w, bb[2] + pad), min(h, bb[3] + pad)))


def _smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def set_aspect(im: Image.Image, target_aspect: float) -> Image.Image:
    """Pill'i hedef orana getirir; yildiz kapaklar 1:1 kalir.

    Kapak/orta arasinda SERT kesim denendi ve calismadi: ozellikle cok
    sikisan gri pasif pill'de birlesim yerinde gorunur bir dikey Mach
    bandi kaliyordu. Bunun yerine surekli bir sutun haritasi: turev
    kapaklarda tam 1, ortada sabit, arada smoothstep. Hicbir yerde
    sicrama yok.
    """
    w, h = im.size
    a = round(h * target_aspect)
    u0 = round(w * CAP) / a
    r = RAMP * u0
    u = (np.arange(a) + 0.5) / a
    g = _smoothstep((u - (u0 - r)) / (2 * r)) * _smoothstep((((1 - u0) + r) - u) / (2 * r))
    c = (w - a) / (a * g.mean())
    deriv = 1.0 + c * g
    assert deriv.min() > 0.05, "sutun haritasi monoton degil"
    s = np.concatenate(([0.0], np.cumsum(deriv)))[:a]
    s *= (w - 1) / max(s[-1], 1e-6)

    src = np.asarray(im, dtype=np.float32)
    i0 = np.floor(s).astype(int)
    i1 = np.minimum(i0 + 1, w - 1)
    f = (s - i0).astype(np.float32)[None, :, None]
    out = src[:, i0, :] * (1 - f) + src[:, i1, :] * f
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def button(src: Image.Image, size) -> Image.Image:
    return set_aspect(body_crop(src), size[0] / size[1]).resize(size, Image.LANCZOS)


def save(im: Image.Image, path: str) -> None:
    im.save(path, optimize=True)
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    print(f"  {rel:44} {im.size[0]}x{im.size[1]}  {os.path.getsize(path) // 1024} KB")


def main() -> None:
    states = load("button_blue_states_normal_selected.png")
    grey = load("button_grey_disabled.png")
    normal = states.crop(BTN_NORMAL_CROP)
    selected = states.crop(BTN_SELECTED_CROP)

    print("guc ikonlari ->")
    save(square(load("power_bomb_icon.png"), 256), os.path.join(UI, "power_bomb.png"))
    save(square(load("power_upgrade_icon.png"), 256), os.path.join(UI, "power_upgrade.png"))
    save(square(load("power_cleaner_icon.png"), 256), os.path.join(UI, "power_clear.png"))
    # Sarsinti tekil dosya olarak YOK, yalnizca sheet icinde.
    shake = load("power_icons_bomb_upgrade_shake_sheet.png").crop(SHAKE_CROP)
    save(square(shake, 256), os.path.join(UI, "power_shake.png"))

    print("butonlar ->")
    save(button(normal, POWER_SIZE), os.path.join(UI, "power_button_normal.png"))
    save(button(selected, POWER_SIZE), os.path.join(UI, "power_button_selected.png"))
    save(button(grey, POWER_SIZE), os.path.join(UI, "power_button_disabled.png"))
    save(button(normal, CTA_SIZE), os.path.join(UI, "cta_button_normal.png"))
    save(button(grey, CTA_SIZE), os.path.join(UI, "cta_button_disabled.png"))

    print("kap / zemin ->")
    night = load("gameplay_background_candy_night.png").convert("RGB")
    save(night, os.path.join(UI, "board_background_night.png"))
    wall = load("board_wall_bamboo_vertical.png").crop(WALL_CROP).convert("RGB")
    save(wall.resize((64, 1080), Image.LANCZOS), os.path.join(UI, "board_wall_bamboo.png"))
    save(fit_w(load("board_floor_bamboo_horizontal.png"), 1024),
         os.path.join(UI, "board_floor_bamboo.png"))

    print("pencere tepeligi ->")
    save(fit_w(load("panel_header_winged_heart_crown.png"), 1024),
         os.path.join(UI, "panel_candy_crown.png"))

    print("efektler ->")
    fx_sheet = load("power_fx_bomb_impact_upgrade_sheet.png")
    save(square(load("power_bomb_projectile.png"), 256),
         os.path.join(FX, "fx_bomb_projectile.png"))
    save(square(fx_sheet.crop(BOMB_IMPACT_CROP), 512), os.path.join(FX, "fx_bomb_impact.png"))
    save(square(fx_sheet.crop(UPGRADE_BEAM_CROP), 512), os.path.join(FX, "fx_upgrade_beam.png"))
    save(square(load("fx_soft_puff_cloud.png"), 512), os.path.join(FX, "fx_puff_cloud.png"))
    save(square(load("fx_magic_star_swirl.png"), 512), os.path.join(FX, "fx_star_swirl.png"))


if __name__ == "__main__":
    main()
