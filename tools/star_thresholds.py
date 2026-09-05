"""Yildiz esiklerini uretir (GAME_DESIGN.md §5.1).

Model: ideal oyun. Her drop tier 1-3'ten uniform gelir, ayni tier'dan iki
parca olunca birleşir. Bir tier'a ulasmak icin gereken merge SAYILARI oyuncu
becerisinden bagimsiz oldugu icin, o tier'a ulasildigi andaki skor dagilimi
bu modelle dogru cikar; beceri sadece hayatta kalip kalmadigini belirler.

2 yildiz = dagilimin p50'si, 3 yildiz = p85'i.

Skor tablosu degisirse bu script tekrar calistirilmali ve cikan degerler
scripts/game/tier_config.gd icindeki SCORE_P50 / SCORE_P85 dizilerine
yazilmalidir.

Kullanim:  python tools/star_thresholds.py
"""
import random

# tier -> o tier'a birlesildiginde kazanilan puan (tier_config.gd ile ayni)
MERGE_SCORE = {2: 50, 3: 70, 4: 90, 5: 110, 6: 130, 7: 150, 8: 200}

DROP_POOL_MAX_TIER = 3
SAMPLES = 40000
TARGET_TIERS = [4, 5, 6, 7, 8]


def score_at_tier(target):
    counts = [0] * 9
    score = 0
    while True:
        counts[random.randint(1, DROP_POOL_MAX_TIER)] += 1
        merged = True
        while merged:
            merged = False
            for tier in range(1, 8):
                if counts[tier] >= 2:
                    counts[tier] -= 2
                    counts[tier + 1] += 1
                    score += MERGE_SCORE[tier + 1]
                    merged = True
                    if tier + 1 == target:
                        return score


def percentile(sorted_values, fraction):
    index = min(len(sorted_values) - 1, int(fraction * len(sorted_values)))
    return sorted_values[index]


def main():
    p50 = [0] * 9
    p85 = [0] * 9
    print("tier |    p5    p50    p85    p95")
    for target in TARGET_TIERS:
        samples = sorted(score_at_tier(target) for _ in range(SAMPLES))
        p50[target] = percentile(samples, 0.50)
        p85[target] = percentile(samples, 0.85)
        print("  %d  | %5d  %5d  %5d  %5d" % (
            target, percentile(samples, 0.05), p50[target],
            p85[target], percentile(samples, 0.95)))

    print()
    print("tier_config.gd icin:")
    print("const SCORE_P50: Array[int] = %s" % _gd_array(p50))
    print("const SCORE_P85: Array[int] = %s" % _gd_array(p85))


def _gd_array(values):
    return "[" + ", ".join(str(v) for v in values) + "]"


if __name__ == "__main__":
    main()
