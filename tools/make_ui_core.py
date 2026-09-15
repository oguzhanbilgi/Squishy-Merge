"""M8.6-01 — Production UI cekirdek asset'leri (LayerLab yapisal katmani).

Kaynak paket (owner lisansli, repoda DEGIL, `.gdignore`'lu):
    _visual_source/layerlab_casual_game/extracted/Assets/Layer Lab/GUI Pro-CasualGame/
Cikti:
    assets/visual/ui/core/<aile>/*.png     turetilmis, beyaz, modulate ile boyanan sprite'lar
    scripts/ui/ui_core_assets.gd           9-slice kenar tablosu (URETILIR, elle duzenlenmez)

Secim politikasi docs/UI_VISUAL_SYSTEM.md §LayerLab: yalnizca USE (ve
kontrollu MAYBE) aileleri. Renkli butonlar, RPG/klan/pass/sandik/gem sanati,
brawler HUD parcalari, kurdele DISINDAKI renkli basliklar, fontlar ve Unity
kodu BILEREK alinmiyor.

Neden pre-scale: Godot NinePatchRect/StyleBoxTexture kose parcalarini piksel
boyutunda cizer; paketin 1440p referansindaki 175 px CTA 720x1280 portrede
88 px olmali. Unity `.meta` `spriteBorder` (x=sol, y=alt, z=sag, w=ust) ayni
olcekle kucultulup Godot marginlerine yaziliyor.

Kullanim:  python tools/make_ui_core.py
"""
from __future__ import annotations

import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_visual_source", "layerlab_casual_game", "extracted",
                   "Assets", "Layer Lab", "GUI Pro-CasualGame", "ResourcesData",
                   "Sprites", "Components")
OUT = os.path.join(ROOT, "assets", "visual", "ui", "core")
REGISTRY = os.path.join(ROOT, "scripts", "ui", "ui_core_assets.gd")

PICTO = "Icon_PictoIcons/128/"

# aile -> { ad: (kaynak, olcek) }. Olcek 1.0 = paketin kendi pikseli.
SPRITES: dict[str, dict[str, tuple[str, float]]] = {
    "panels": {
        # Pencere govdesi (krem modal): govde + ust isik + ust cizgi + parilti
        "popup_body": ("Popup/Popoup01~03_White_Bg.png", 1.0),
        "popup_light": ("Popup/Popoup01~03_White_LIght.png", 1.0),
        "popup_topline": ("Popup/Popoup01~03_White_Bg_TopLine.png", 1.0),
        "popup_glow": ("Popup/Common_Popup_Glow.png", 0.5),
        # Plakalar (HUD skor/hedef, ayarlar satirlari)
        "panel_round": ("Frame/PanelFrame01_Round_Bg.png", 1.0),
        "panel_bevel": ("Frame/PanelFrame02_Round_White_bg.png", 1.0),
        "panel_bevel_light": ("Frame/PanelFrame02_Round_White_InnerTop1.png", 1.0),
        # Kartlar
        "card_large": ("Frame/CardFrame08_White.png", 0.5),
        "card_bevel": ("Frame/CardFrame03_White.png", 1.0),
        "card_bevel_soft": ("Frame/CardFrame03_White.png", 1.0),
        "card_flat": ("Frame/CardFrame01_Bg.png", 1.0),
        "card_border": ("Frame/CardFrame01_Border.png", 1.0),
        "list_row": ("Frame/ListFrame01_Bg.png", 1.0),
        # Item cerceveleri / ikon kuyulari
        "item_frame": ("Frame/ItemFrame04_White1.png", 1.0),
        "item_frame_inner": ("Frame/ItemFrame04_White2_Inner.png", 1.0),
        "item_circle": ("Frame/ItemFrame02_White1.png", 0.5),
        "item_circle_inner": ("Frame/ItemFrame02_White2_Inner.png", 0.5),
        "item_focus": ("Frame/ItemFrame01_f.png", 0.5),
        # Ince cerceveler ve temel yuvarlak dolgular
        "border_round": ("Frame/BorderFrame_Round02.png", 1.0),
        "border_round_thin": ("Frame/BorderFrame_Round03.png", 1.0),
        "frame_round12": ("Frame/BasicFrame_Round12.png", 1.0),
        "frame_round20": ("Frame/BasicFrame_Round20.png", 1.0),
    },
    "buttons": {
        # Button01 ailesi: ayni govde dort yukseklikte (hero 88 / large 72 /
        # normal 58 / compact 44) — kose ve bevel govdeyle birlikte olcekleniyor.
        "btn_cta": ("Button/Button01_175_White.png", 0.5),
        "btn_large": ("Button/Button01_145_White.Png", 0.5),
        "btn_normal": ("Button/Button01_145_White.Png", 0.4),
        "btn_compact": ("Button/Button01_145_White.Png", 0.3),
        "btn_bevel": ("Button/Button03_White_Bg.png", 1.0),
        "btn_bevel_light": ("Button/Button03_White_Light.png", 1.0),
        # HUD v5 yumusak govde: ayni bevel, siyah cizgi tint*0.44 koyuluga
        # kaldirilmis, dis golge yari saydam (SOFTEN) — candy/plastik his.
        "btn_bevel_soft": ("Button/Button03_White_Bg.png", 1.0),
        "btn_square": ("Button/Button_Square01_White.png", 1.0),
        "btn_square_sm": ("Button/Button_Square03_White.png", 1.0),
        "btn_square_flat": ("Button/Button_Square04.png", 0.5),
        "btn_circle": ("Button/Button_Circle147_White.png", 0.5),
        "btn_circle_flat": ("Button/Button_Circle128_White.png", 0.5),
    },
    "labels": {
        "label_round": ("Label/Label_Round01_White.png", 1.0),
        # Kucuk rozet govdesi (stok x4, 12/20): ayni etiket yarim olcekte,
        # tam olcek 66 px minimumun altinda ezilip kare gorunuyordu.
        "badge_round": ("Label/Label_Round01_White.png", 0.5),
        "label_trapezoid": ("Label/Label_Trapezoid_White_Bg.png", 1.0),
        "label_bubble": ("Label/Label_Bubble01.png", 1.0),
        "label_ribbon": ("Label/Label_Ribbon_White_Bg.png", 1.0),
        "label_ribbon_light": ("Label/Label_Ribbon_White_Light.png", 1.0),
        "title_oval": ("Label/Title_Oval.png", 1.0),
        # Baslik kurdelesi: paketin yalnizca renkli surumu var (MAYBE grubu);
        # asagida WHITEN ile beyaza indirgenip modulate ile boyaniyor.
        "header_ribbon": ("Label/Title_Ribbon_Bg_Yellow.png", 0.5),
    },
    "resources": {
        "resource_bar": ("UI_Etc/ResourceBar_Bg.png", 1.0),
        "resource_btn": ("UI_Etc/ResourceBar_Btn_Bg.png", 1.0),
        "resource_btn_light": ("UI_Etc/ResourceBar_Btn_Light.png", 1.0),
        "resource_add": ("UI_Etc/ResourceBar_Btn_Icon_Add.png", 1.0),
    },
    "progress": {
        "slider_bg": ("Slider/Slider_Basic02_Bg.png", 1.0),
        "slider_fill": ("Slider/Slider_Basic02_Fill_White.png", 1.0),
        "slider_thin_bg": ("Slider/Slider_Basic01_Bg.png", 1.0),
        "slider_thin_fill": ("Slider/Slider_Basic01_Fill_White.png", 1.0),
        "slider_fill_sm": ("Slider/Slider_Basic01_Fill_White.png", 0.4),
        # Anahtar (MAYBE grubu, beyaz tabanlar): ray + topuz
        "switch_track": ("UI_Etc/Switch_Bg_White.png", 0.75),
        "switch_knob": ("UI_Etc/Switch_Handle_White.png", 0.75),
        # Onay kutusu (beyaz tabanlar)
        "checkbox_bg": ("UI_Etc/Toggle02_CheckBox_White_bg.png", 0.5),
        "checkbox_border": ("UI_Etc/Toggle02_CheckBox_White_Border.png", 0.5),
        "checkbox_check": ("UI_Etc/Toggle02_CheckBox_Icon_White.png", 0.5),
    },
    "badges": {
        "alert_dot": ("UI_Etc/Alert_Dot_Bg.png", 1.0),
        "alert_dot_ring": ("UI_Etc/Alert_Dot_Border.png", 0.5),
    },
}

# Renkli kaynaktan beyaz taban: parlaklik (V) tabanli gri, golgeli yuzler
# gamma ile ayrilir ki modulate sonrasi kurdelenin kivrimi okunsun.
WHITEN: set[str] = {"header_ribbon"}
WHITEN_GAMMA = 3.0

# Yumusatma (HUD v5): pismis siyah cizgi/bevel griye kaldirilir — modulate
# carpani oldugundan cizgi tint'in koyu tonu olur (siyah degil, erik/koyu
# lavanta); tam saydam olmayan dis golge pikselleri yari alfa.
SOFTEN: set[str] = {"btn_bevel_soft", "card_bevel_soft"}
SOFTEN_FLOOR = 0.44
SOFTEN_SHADOW_ALPHA = 0.5

# Beyaz picto ikon ailesi: rol -> paket adi. Squishy Merge'in kendi sanati
# olan kavramlar (Hamur, guc, skin, sandik, tac/yildiz/bayrak HUD rozetleri)
# BURADA YOK — onlar assets/visual/ui/ altindaki owner asset'leri.
ICONS: dict[str, str] = {
    "back": "Pictoicon_Arrow_Backward",
    "close": "PictoIcon_Close",
    "settings": "Pictoicon_Setting",
    "sound_on": "Pictoicon_Volume_On",
    "sound_off": "Pictoicon_Volume_Off",
    "vibration": "Pictoicon_Haptic",
    "info": "Pictoicon_Info",
    "help": "Pictoicon_Help",
    "home": "Pictoicon_Home_1",
    "shop": "Pictoicon_Shop_1",
    "collection": "Pictoicon_Book_0",
    "map": "Pictoicon_Map_1",
    "check": "PictoIcon_Check",
    "lock": "Pictoicon_Lock",
    "unlock": "Pictoicon_Unlock",
    "plus": "PictoIcon_Plus",
    "minus": "PictoIcon_Minus",
    "arrow_next": "Pictoicon_Arrow_Next",
    "arrow_prev": "Pictoicon_Arrow_Prev",
    "arrow_up": "Pictoicon_Arrow_Up",
    "arrow_down": "Pictoicon_Arrow_Down",
    "gift": "Pictoicon_Gift",
    "trophy": "Pictoicon_Trophy_0",
    "play": "Pictoicon_Control_Play",
    "pause": "Pictoicon_Control_Pause",
    "movie": "Pictoicon_Movie",
    "refresh": "Pictoicon_Refresh",
    "target": "Pictoicon_Target",
    "goal": "Pictoicon_Goal",
    "calendar": "Pictoicon_Calendar",
    "confirm": "Pictoicon_Confirm",
    "bell": "Pictoicon_Bell",
}

BORDER_RE = re.compile(r"spriteBorder: \{x: ([\d.]+), y: ([\d.]+), z: ([\d.]+), w: ([\d.]+)\}")


def read_border(meta_path: str) -> tuple[float, float, float, float]:
    """Unity spriteBorder -> (sol, ust, sag, alt)."""
    if not os.path.exists(meta_path):
        return (0, 0, 0, 0)
    with open(meta_path, encoding="utf-8", errors="replace") as f:
        m = BORDER_RE.search(f.read())
    if not m:
        return (0, 0, 0, 0)
    x, y, z, w = (float(v) for v in m.groups())
    return (x, w, z, y)


def whiten(im: Image.Image, gamma: float) -> Image.Image:
    px = im.load()
    out = Image.new("RGBA", im.size)
    op = out.load()
    vmax = 1
    for yy in range(im.height):
        for xx in range(im.width):
            r, g, b, a = px[xx, yy]
            if a > 8:
                vmax = max(vmax, r, g, b)
    for yy in range(im.height):
        for xx in range(im.width):
            r, g, b, a = px[xx, yy]
            v = (max(r, g, b) / vmax) ** gamma
            gray = int(round(255 * v))
            op[xx, yy] = (gray, gray, gray, a)
    return out


def soften(im: Image.Image, floor: float, shadow_alpha: float) -> Image.Image:
    px = im.load()
    out = Image.new("RGBA", im.size)
    op = out.load()
    lo = int(round(255 * floor))
    for yy in range(im.height):
        for xx in range(im.width):
            r, g, b, a = px[xx, yy]
            if a < 250 and max(r, g, b) < 40:
                a = int(round(a * shadow_alpha))
            v = max(r, g, b, lo) if a > 0 else 0
            op[xx, yy] = (v, v, v, a)
    return out


def find_picto(name: str) -> str:
    folder = os.path.join(SRC, PICTO)
    for entry in os.listdir(folder):
        stem, ext = os.path.splitext(entry)
        if ext.lower() == ".png" and stem.lower() == name.lower():
            return os.path.join(folder, entry)
    raise FileNotFoundError(name)


def derive(src: str, scale: float, do_whiten: bool) -> tuple[Image.Image, tuple[int, int, int, int]]:
    im = Image.open(src).convert("RGBA")
    l, t, r, b = read_border(src + ".meta")
    if scale != 1.0:
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        im = im.resize(size, Image.LANCZOS)
        l, t, r, b = (v * scale for v in (l, t, r, b))
    if do_whiten:
        im = whiten(im, WHITEN_GAMMA)
    # Sabit yukseklikli/genislikli parcalarda (ust+alt == yukseklik) ortada
    # 0 px esneme bolgesi kalir; Godot bunu kabul etmiyor -> 1 px pay.
    if t + b >= im.height:
        t, b = im.height // 2 - 1, im.height - im.height // 2
    if l + r >= im.width:
        l, r = im.width // 2 - 1, im.width - im.width // 2
    return im, (int(l), int(t), int(r), int(b))


def main() -> None:
    lines = [
        "class_name UiCoreAssets",
        "extends RefCounted",
        "## URETILMIS DOSYA — tools/make_ui_core.py. Elle duzenleme.",
        "## Production UI cekirdek sprite'lari (assets/visual/ui/core/) ve 9-slice",
        "## kenarlari. Deger: [yol, genislik, yukseklik, sol, ust, sag, alt].",
        "",
        "const ROOT: String = \"res://assets/visual/ui/core/\"",
        "",
        "const SPRITES: Dictionary = {",
    ]
    count = 0
    for family, entries in SPRITES.items():
        folder = os.path.join(OUT, family)
        os.makedirs(folder, exist_ok=True)
        for name, (rel, scale) in entries.items():
            im, (l, t, r, b) = derive(os.path.join(SRC, rel), scale, name in WHITEN)
            if name in SOFTEN:
                im = soften(im, SOFTEN_FLOOR, SOFTEN_SHADOW_ALPHA)
            im.save(os.path.join(folder, name + ".png"))
            lines.append("\t\"%s\": [\"%s/%s.png\", %d, %d, %d, %d, %d, %d]," % (
                name, family, name, im.width, im.height, l, t, r, b))
            count += 1
    lines += ["}", "", "## Beyaz picto ikonlar (128 px). rol -> yol.", "const ICONS: Dictionary = {"]
    folder = os.path.join(OUT, "icons")
    os.makedirs(folder, exist_ok=True)
    for role, picto in ICONS.items():
        im = Image.open(find_picto(picto)).convert("RGBA")
        im.save(os.path.join(folder, role + ".png"))
        lines.append("\t\"%s\": \"icons/%s.png\"," % (role, role))
        count += 1
    lines += ["}", ""]
    with open(REGISTRY, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("yazildi:", count, "asset ->", OUT, "+", REGISTRY)


if __name__ == "__main__":
    main()
