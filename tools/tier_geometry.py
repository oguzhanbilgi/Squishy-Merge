"""Tier yaricaplarinin dar kapta (level 10) fiziksel olarak sigip sigmadigini olcer.

Sorun (owner playtest, M8): L9/L10 kazanilamiyor. Kok sebep kap genisligi degil,
tier 7-8'in yaricaplari: en dar kapta (370x400 px) tier 8'e ulasmak icin gereken
yigin, kabin alanina sigmiyor.

Model: star_thresholds.py ile ayni ideal-oyun modeli (her drop tier 1-3'ten
uniform, ayni tier'dan iki parca aninda birleşir). Fark: burada skor degil,
yiginin O ANDAKI toplam daire ALANI izleniyor.

Neden bu dogru bir olcut: ideal oyunda bile yigin bir "ikili sayac" gibi
davranir -- tier 8'i yapmak icin bir an iki tane tier 7'yi AYNI ANDA tutmak
zorundasin, altlarinda da her tier'dan artakalanlarla. O andaki toplam alan
kabin alanindan buyukse level insan oyuncu icin de imkansizdir; kucukse
oynanabilirlik paketleme verimine kalir (bunu headless bot dogruluyor).

Kullanim:  python tools/tier_geometry.py
"""
import math
import random

DROP_POOL_MAX_TIER = 3
SAMPLES = 20000
MERGE_SCORE = {2: 50, 3: 70, 4: 90, 5: 110, 6: 130, 7: 150, 8: 200}

# Level 10 geometrisi (GAME_DESIGN.md §3, resources/levels/level_10.tres)
CONTAINER_WIDTH = 370.0
PLAYABLE_HEIGHT = 400.0
TARGET_SCORE = 5000

# Doluluk esikleri M8'de headless bot ile KALIBRE EDILDI. Onceki degerler
# (0.60/0.75) teorik paketleme veriminden tahmin edilmisti ve fena halde
# iyimserdi: mevcut geometri %64 doluluk icin "ZOR" diyordu, oysa bot 20
# kosuda tier 8'e bir kez bile ulasamadi.
#
# Olculen esleme (L10, n=30-40, tools/bot_runner.gd):
#   %32 doluluk -> %60 kazanma      %42 -> %27
#   %37         -> %53              %48 -> %23
#   %40         -> hedef band       %64 -> %0  (imkansiz)
#
# Yigin bir kutuyu hicbir zaman doldurmaz: ustu puruzlu kalir, buyuk parcalar
# arasindaki bosluklara kucukleri oturtmak oyuncunun kontrolunde degil.
# Gercekci tavan bu yuzden teorik ~0.85'in cok altinda.
COMFORTABLE_FILL = 0.40
HARD_FILL = 0.50

# UYARI (M8): bu model TEK BASINA yeterli degil. Alan hesabi mevcut
# yaricaplar icin "%64 doluluk / ZOR" diyordu, oysa headless bot ayni
# geometride 20 kosuda tier 8'e BIR KEZ BILE ulasamadi. Eksik olan sey
# yiginin YUKSEKLIGI: oynanabilir yukseklik 400 px sabit ve iki tier-7'yi
# yan yana koyduktan sonra alttaki artik merdivenin gidecek yeri kalmiyor.
# Bu yuzden yaricap karari tools/bot_runner.gd ile dogrulanmali; burasi
# sadece aday daraltmak icin.

# M8 oncesi merdiven — L9/L10 bununla kazanilamiyordu (bot: L10'da 0/20).
LEGACY = [22.0, 30.0, 40.0, 52.0, 66.0, 84.0, 106.0, 132.0]
# M8'de yururluge giren merdiven: tier 1 sabit, buyume orani 1.2415 sabit.
CURRENT = [22.0, 27.0, 34.0, 42.0, 52.0, 65.0, 81.0, 100.0]


def area(radii, counts):
    return sum(counts[t] * math.pi * radii[t - 1] ** 2 for t in range(1, 9))


def simulate_run(radii):
    """Bir kosuyu ideal oyunla oynar.

    Doner: (tier 8 anina kadarki tepe alan, tier 8'den sonra 5000 skora
    ulasilana kadarki tepe alan, tier 8 icin gereken drop sayisi,
    5000 skora ulasmak icin gereken toplam drop sayisi)
    """
    counts = [0] * 9
    score = 0
    drops = 0
    peak_before = 0.0
    peak_after = 0.0
    drops_to_tier8 = None
    reached_8 = False

    while True:
        counts[random.randint(1, DROP_POOL_MAX_TIER)] += 1
        drops += 1
        merged = True
        while merged:
            merged = False
            for tier in range(1, 8):
                if counts[tier] >= 2:
                    # Birleşmeden HEMEN ONCE iki parca da tahtada: tepe an bu.
                    snapshot = area(radii, counts)
                    if reached_8:
                        peak_after = max(peak_after, snapshot)
                    else:
                        peak_before = max(peak_before, snapshot)
                    counts[tier] -= 2
                    counts[tier + 1] += 1
                    score += MERGE_SCORE[tier + 1]
                    merged = True
                    if tier + 1 == 8 and not reached_8:
                        reached_8 = True
                        drops_to_tier8 = drops
        if reached_8 and score >= TARGET_SCORE:
            return peak_before, peak_after, drops_to_tier8, drops


def percentile(sorted_values, fraction):
    index = min(len(sorted_values) - 1, int(fraction * len(sorted_values)))
    return sorted_values[index]


def evaluate(label, radii):
    container = CONTAINER_WIDTH * PLAYABLE_HEIGHT
    before, after, d8, dtotal = [], [], [], []
    for _ in range(SAMPLES):
        b, a, n8, nt = simulate_run(radii)
        before.append(b)
        after.append(a)
        d8.append(n8)
        dtotal.append(nt)
    before.sort()
    after.sort()
    d8.sort()
    dtotal.sort()

    peak = max(percentile(before, 0.50), percentile(after, 0.50))
    peak95 = max(percentile(before, 0.95), percentile(after, 0.95))

    print("--- %s ---" % label)
    print("  yaricaplar          : %s" % ", ".join("%g" % r for r in radii))
    print("  tier 8 capi         : %.0f px  (kap ici genislik %.0f)"
          % (radii[7] * 2, CONTAINER_WIDTH))
    print("  iki tier 7 yan yana : %.0f px  (%s)"
          % (radii[6] * 4,
             "sigar" if radii[6] * 4 <= CONTAINER_WIDTH else "SIGMAZ, capraz dizilmeli"))
    print("  tepe yigin alani    : p50 %.0f  p95 %.0f px^2" % (peak, peak95))
    print("  kap alani           : %.0f px^2" % container)
    print("  doluluk orani       : p50 %.0f%%  p95 %.0f%%"
          % (100 * peak / container, 100 * peak95 / container))
    verdict = ("RAHAT" if peak95 / container <= COMFORTABLE_FILL
               else "ZOR" if peak95 / container <= HARD_FILL
               else "IMKANSIZ")
    print("  hukum               : %s" % verdict)
    print("  drop sayisi         : tier 8 icin p50 %d, 5000 skor icin p50 %d"
          % (percentile(d8, 0.50), percentile(dtotal, 0.50)))
    print("  90 sn'de (0.4s cd)  : en fazla 225 drop -> %s"
          % ("yeterli" if percentile(dtotal, 0.95) < 225 else "SURE YETMEZ"))
    print()
    return peak95 / container


def ladder(r8, r1=22.0):
    """Sabit oranli merdiven: r1 sabit, oran r8 hedefine gore secilir."""
    k = (r8 / r1) ** (1.0 / 7.0)
    return [float(round(r1 * k ** i)) for i in range(8)]


def main():
    print("Level 10 kabi: %.0f x %.0f px\n" % (CONTAINER_WIDTH, PLAYABLE_HEIGHT))
    evaluate("M8 ONCESI (r8=132)", LEGACY)
    evaluate("YURURLUKTEKI (r8=100)", CURRENT)
    # M8'de taranan aday araligi; asil karar headless bot ile verildi
    # (bkz. yukaridaki UYARI ve GAME_DESIGN.md §2).
    for r8 in (83, 95, 105, 115):
        evaluate("ADAY r8=%d" % r8, ladder(r8))


if __name__ == "__main__":
    main()
