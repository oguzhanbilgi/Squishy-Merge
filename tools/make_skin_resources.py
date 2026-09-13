"""20 skin .tres dosyasini TEK tablodan uretir (M8.5-14).

    python tools/make_skin_resources.py

Cikti: resources/skins/<id>.tres — SkinData alanlari (scripts/game/skin_data.gd):
kimlik + final onizleme (assets/visual/skins/previews/skin_<rarity>_<ad>.png)
+ gameplay render profili (assets/visual/skins/skin_body.gdshader parametreleri).

Kural: id'ler SABIT (kayit dosyasi bunlari tutuyor), fiyat rarity'den geliyor
(Shop.PRICES, burada yok). Renk/desen degistirmek icin bu tabloyu duzenle ve
yeniden calistir; .tres'leri elle duzenleme.

Renk notasyonu: hex "rrggbb". Alanlar:
  body / shade / hi     govde orta ton / golge / parlama
  pattern               SkinData.Pattern adi
  pc / pc2              desen renkleri
  dens / scale / str    yogunluk / hucre olcegi / guc
  gloss / pearl / spark rarity malzemesi
  aura                  Legendary aura rengi (None = yok)
  speed                 animasyon hizi
"""
import os

OUT = "resources/skins"
PREVIEW = "res://assets/visual/skins/previews/skin_{}.png"

PATTERNS = ["NONE", "SPECKLE", "FLECK", "RING", "MARBLE", "SWIRL", "CRYSTAL",
            "STREAK", "WAVE", "IRIDESCENT", "METAL"]
RARITY = {"common": 0, "rare": 1, "epic": 2, "legendary": 3}


def P(body, shade, hi="ffffff", pattern="NONE", pc="000000", pc2="ffffff",
      dens=0.5, scale=1.0, strength=0.8, gloss=0.0, pearl=0.0, spark=0.0,
      aura=None, speed=1.0):
    return dict(body=body, shade=shade, hi=hi, pattern=pattern, pc=pc, pc2=pc2,
                dens=dens, scale=scale, strength=strength, gloss=gloss,
                pearl=pearl, spark=spark, aura=aura, speed=speed)


# id, rarity, gorsel dosya adi, gosterilen ad, profil
SKINS = [
    # --- COMMON: govde/malzeme/desen, aura yok ---
    ("common_01", "common", "sade", "Sade",
     P("f6e9cf", "c9a97e", "fffaf0")),
    ("common_02", "common", "susamli", "Susamlı",
     P("f2e3c4", "c4a274", "fff8ea", "SPECKLE", "2a2018", "fff3d6", dens=0.55, scale=1.15, strength=0.95)),
    ("common_03", "common", "kepekli", "Kepekli",
     P("e2c9a0", "a97f55", "f9eed8", "FLECK", "7a4f2c", "b98a5c", dens=0.7, scale=1.4, strength=0.75)),
    ("common_04", "common", "havuclu", "Havuçlu",
     P("f5b06a", "c46f2a", "ffe3c0", "FLECK", "e26a1e", "f8c78a", dens=0.6, scale=1.1, strength=0.85)),
    ("common_05", "common", "yesil_sogan", "Yeşil Soğan",
     P("dcedb6", "8fae5c", "f6fce6", "RING", "4f8a2d", "8fc95a", dens=0.45, scale=1.1, strength=0.85)),
    ("common_06", "common", "misir", "Mısır",
     P("f7d13a", "c2911a", "fff4bf", "FLECK", "e9a715", "fff0a8", dens=0.5, scale=1.0, strength=0.7)),
    ("common_07", "common", "peynirli", "Peynirli",
     P("f7d472", "cb9a2a", "fff7d2", "NONE", gloss=0.35)),
    ("common_08", "common", "sarimsakli", "Sarımsaklı",
     P("efe0c2", "b9976a", "fff9ec", "SPECKLE", "9c6b3a", "d9b98a", dens=0.4, scale=1.4, strength=0.7)),
    # --- RARE: daha zengin malzeme, aura yok ---
    ("rare_01", "rare", "karabiber", "Karabiber",
     P("e3d3b8", "a08560", "fff8ea", "SPECKLE", "1f1a16", "5a4a3a", dens=0.6, scale=1.5, strength=0.95, gloss=0.2)),
    ("rare_02", "rare", "kirmizi_biber", "Kırmızı Biber",
     P("f0714a", "b33a1c", "ffd2b8", "FLECK", "c81f12", "ffb27a", dens=0.6, scale=1.2, strength=0.85, gloss=0.3)),
    ("rare_03", "rare", "mantar", "Mantar",
     P("d9bd9c", "8f6a47", "f6ead6", "MARBLE", "9a7352", strength=0.55, scale=1.1, gloss=0.15)),
    ("rare_04", "rare", "ispanak", "Ispanak",
     P("8fc45c", "4c7a2b", "dff5c4", "FLECK", "2f5d1a", "6da03f", dens=0.6, scale=1.2, strength=0.85, gloss=0.25)),
    ("rare_05", "rare", "deniz_tuzu", "Deniz Tuzu",
     P("8fdcf0", "3f96b8", "eafcff", "CRYSTAL", "ffffff", "d8fbff", dens=0.7, scale=1.2, strength=1.0, gloss=0.4, pearl=0.25)),
    ("rare_06", "rare", "zencefil", "Zencefil",
     P("e9a54a", "a8621a", "ffe3ae", "SWIRL", "b8651a", strength=0.75, scale=1.0, gloss=0.3)),
    # --- EPIC: zengin malzeme + kucuk imza efekti (sparkle) ---
    ("epic_01", "epic", "aci_sos", "Acı Sos",
     P("ef6a2c", "9f2a10", "ffd9a8", "STREAK", "c8230f", "ffb35a", dens=0.5, scale=1.1, strength=0.8, gloss=0.6, spark=0.35, speed=1.2)),
    ("epic_02", "epic", "yosun", "Yosun",
     P("2f9c8c", "155248", "b8f3e6", "WAVE", "0f6b5e", "cfffee", dens=0.5, scale=1.1, strength=0.8, gloss=0.5, spark=0.3, speed=0.8)),
    ("epic_03", "epic", "kakao", "Kakao",
     P("8a5233", "42210f", "e3b894", "MARBLE", "4a2410", strength=0.85, scale=1.2, gloss=0.55, spark=0.3)),
    ("epic_04", "epic", "safran", "Safran",
     P("f2b135", "b46f10", "fff0b8", "SWIRL", "c96a12", strength=0.85, scale=1.2, gloss=0.5, spark=0.4)),
    # --- LEGENDARY: en guclu malzeme + kompakt aura ---
    ("legendary_01", "legendary", "altin_hamur", "Altın Hamur",
     P("f5c53a", "a8710e", "fff6c8", "METAL", "fff2a6", strength=0.9, scale=1.0, gloss=0.9, pearl=0.2, spark=0.7, aura="ffd15a", speed=1.0)),
    ("legendary_02", "legendary", "gokkusagi", "Gökkuşağı",
     P("f2d8f5", "a988c4", "ffffff", "IRIDESCENT", "ffffff", "ffffff", strength=0.85, scale=1.0, gloss=0.6, pearl=0.7, spark=0.6, aura="e6b8ff", speed=1.0)),
]


def col(hex_str, alpha=1.0):
    r = int(hex_str[0:2], 16) / 255.0
    g = int(hex_str[2:4], 16) / 255.0
    b = int(hex_str[4:6], 16) / 255.0
    return "Color(%.4g, %.4g, %.4g, %g)" % (r, g, b, alpha)


def write(skin_id, rarity, file_key, name, p):
    aura = col(p["aura"]) if p["aura"] else "Color(1, 1, 1, 0)"
    body = "\n".join([
        '[gd_resource type="Resource" script_class="SkinData" load_steps=3 format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/game/skin_data.gd" id="1_skin"]',
        '[ext_resource type="Texture2D" path="%s" id="2_preview"]' % PREVIEW.format("%s_%s" % (rarity, file_key)),
        '',
        '[resource]',
        'script = ExtResource("1_skin")',
        'id = &"%s"' % skin_id,
        'display_name = "%s"' % name,
        'rarity = %d' % RARITY[rarity],
        'preview_texture = ExtResource("2_preview")',
        'body_color = %s' % col(p["body"]),
        'shade_color = %s' % col(p["shade"]),
        'highlight_color = %s' % col(p["hi"]),
        'pattern = %d' % PATTERNS.index(p["pattern"]),
        'pattern_color = %s' % col(p["pc"]),
        'pattern_color2 = %s' % col(p["pc2"]),
        'pattern_density = %g' % p["dens"],
        'pattern_scale = %g' % p["scale"],
        'pattern_strength = %g' % p["strength"],
        'gloss = %g' % p["gloss"],
        'pearl = %g' % p["pearl"],
        'sparkle = %g' % p["spark"],
        'aura_color = %s' % aura,
        'anim_speed = %g' % p["speed"],
        '',
    ])
    with open(os.path.join(OUT, skin_id + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(body)


def main():
    assert len(SKINS) == 20
    for row in SKINS:
        write(*row)
    print("20 skin .tres yazildi ->", OUT)


if __name__ == "__main__":
    main()
