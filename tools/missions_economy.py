"""TASK/046 — Günlük / Haftalık Görevler: KÜÇÜK EKLEMELİ ekonomi analizi (deterministik).

Soru: görev Hamur'u (en fazla 30 / gün + 120 / hafta = 330 / hafta) mevcut Hamur gelirinin
yanında ne kadar? Görev sayıları / ödülleri BURADA AYARLANMAZ (owner kararı, kilitli); bu araç
yalnız etkiyi ölçer.

Varsayımlar `tools/shop_economy.py` ile AYNI kaynaktan (bot ölçümleri, M8.5-01 / GAME_DESIGN §3):
level başına merge medyanı + kazanma oranı, sonsuz round'u 179 merge. Oyuncu profili = günde
round sayısı (kasual 3 / orta 5 / yoğun 10) × oynadığı içerik (erken L1-L3, orta L4-L7, geç
L8-L10, sonsuz). Beklenen değer — Monte Carlo değil; sandık Hamur'u beklentisi kilitli oranlardan.
İki koleksiyon durumu ayrı tablo: EKSİK (sandığın %30 parça kurası parça verir → 0 Hamur) ve
TAMAM (rarity tükenince parça yerine o rarity'nin Hamur'u; günlük sandıkta +15 bonus) — tamam
koleksiyonda mevcut gelir daha yüksek, görevin payı daha düşük çıkar.

Kullanım:
  python tools/missions_economy.py
"""
import math
import sys

# tools/ altında __pycache__ bırakmasın (repo temiz kalsın).
sys.dont_write_bytecode = True
# Türkçe tablo başlıkları cp1252 konsolda / yönlendirmede patlamasın.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from shop_economy import LEVELS, ENDLESS_MERGES, RARITY_DOUGH, RARITY_THRESHOLDS, SKIN_REWARD_PERCENT  # noqa: E402
from shop_economy import CONSOLATION, DAILY, MERGES_PER_CHEST  # noqa: E402

# --- Kilitli görev kataloğu (scripts/game/missions.gd CATALOG ile AYNI) ---
DAILY_MISSIONS = [("merges", 15, 10), ("rounds", 2, 10), ("clears", 1, 10)]
WEEKLY_MISSIONS = [("merges", 120, 40), ("rounds", 12, 40), ("clears", 5, 40)]
MAX_PER_WEEK = 7 * sum(r for _, _, r in DAILY_MISSIONS) + sum(r for _, _, r in WEEKLY_MISSIONS)

# Günlük sandık (scripts/game/daily_chest_loot.gd): garanti 15 + %30 parça kurası (tükenirse +15).
DAILY_CHEST_BASE = 15
DAILY_CHEST_EXHAUSTED_BONUS = 15
DAILY_SKIN_CHANCE = 0.30
AD_DOUGH = 150
AD_CHESTS_PER_DAY = 2

PROFILES = [("kasual", 3), ("orta", 5), ("yoğun", 10)]
CONTENT = {
    "erken (L1-L3)": [0, 1, 2],
    "orta (L4-L7)": [3, 4, 5, 6],
    "geç (L8-L10)": [7, 8, 9],
    "sonsuz": None,
}


def chest_dough_mean(collection_complete):
    """Bir sandığın beklenen Hamur'u. Eksik koleksiyon: %70 Hamur × rarity ortalaması (parça
    çıkarsa 0). Tamam koleksiyon: parça kurası da o rarity'nin Hamur'una düşer (§5.2)."""
    probs = []
    prev = 0
    for t in RARITY_THRESHOLDS:
        probs.append((t - prev) / 100.0)
        prev = t
    mean = sum(p * d for p, d in zip(probs, RARITY_DOUGH))
    return mean if collection_complete else (100 - SKIN_REWARD_PERCENT) / 100.0 * mean


def daily_chest_dough(collection_complete):
    """Günlük (ücretsiz / reklamlı) sandığın beklenen Hamur'u: 15 + (tamamsa %30 × 15 bonus)."""
    return DAILY_CHEST_BASE + (DAILY_SKIN_CHANCE * DAILY_CHEST_EXHAUSTED_BONUS if collection_complete else 0.0)


def round_stats(levels):
    """Round başına (merge, kazanma olasılığı, sabit level mi)."""
    if levels is None:
        return ENDLESS_MERGES, 0.0, False
    merges = sum(LEVELS[i][0] for i in levels) / len(levels)
    win = sum(LEVELS[i][1] for i in levels) / len(levels)
    return merges, win, True


def p_at_least(k, n, p):
    """Binom: n denemede en az k başarı olasılığı."""
    return sum(math.comb(n, j) * p ** j * (1 - p) ** (n - j) for j in range(k, n + 1))


def mission_week(rounds_per_day, merges, win, fixed):
    """Haftalık beklenen görev Hamur'u (günlük × 7 + haftalık)."""
    day = 0.0
    for metric, target, reward in DAILY_MISSIONS:
        if metric == "merges":
            day += reward if merges * rounds_per_day >= target else 0.0
        elif metric == "rounds":
            day += reward if rounds_per_day >= target else 0.0
        else:
            day += reward * p_at_least(target, rounds_per_day, win) if fixed else 0.0
    week = 7 * day
    for metric, target, reward in WEEKLY_MISSIONS:
        if metric == "merges":
            week += reward if merges * rounds_per_day * 7 >= target else 0.0
        elif metric == "rounds":
            week += reward if rounds_per_day * 7 >= target else 0.0
        else:
            week += reward * p_at_least(target, rounds_per_day * 7, win) if fixed else 0.0
    return week


def baseline_week(rounds_per_day, merges, win, fixed, ads, collection_complete):
    """Mevcut haftalık Hamur geliri (görev hariç): giriş + ücretsiz günlük sandık + round sandıkları
    (level sandığı + her 75 merge'de bonus + kayıpta teselli); `ads` ise reklamlı +150 + 2 sandık."""
    chest = chest_dough_mean(collection_complete)
    daily_chest = daily_chest_dough(collection_complete)
    per_round = merges / MERGES_PER_CHEST * chest
    if fixed:
        per_round += win * chest + (1 - win) * CONSOLATION
    day = DAILY + daily_chest + rounds_per_day * per_round
    if ads:
        day += AD_DOUGH + AD_CHESTS_PER_DAY * daily_chest
    return 7 * day


def table(collection_complete):
    """Profil × içerik tablosu; (en küçük, en büyük) ek oranı döner (reklamsız, reklamlı)."""
    label = "TAMAM (parça yerine Hamur)" if collection_complete else "EKSİK (parça çıkabilir)"
    print("Koleksiyon %s — sandık başına beklenen Hamur %.1f, günlük sandık %.1f" % (
        label, chest_dough_mean(collection_complete), daily_chest_dough(collection_complete)))
    print()
    print("| profil | içerik | merge/round | görev/hafta | mevcut/hafta (reklamsız) | ek (reklamsız) | mevcut/hafta (reklamlı) | ek (reklamlı) |")
    print("|" + "---|" * 8)
    no_ads = []
    with_ads = []
    for name, rpd in PROFILES:
        for content, levels in CONTENT.items():
            merges, win, fixed = round_stats(levels)
            m = mission_week(rpd, merges, win, fixed)
            b0 = baseline_week(rpd, merges, win, fixed, False, collection_complete)
            b1 = baseline_week(rpd, merges, win, fixed, True, collection_complete)
            no_ads.append(100.0 * m / b0)
            with_ads.append(100.0 * m / b1)
            print("| %s (%d/gün) | %s | %.0f | %.0f | %.0f | +%.0f%% | %.0f | +%.0f%% |" % (
                name, rpd, content, merges, m, b0, 100.0 * m / b0, b1, 100.0 * m / b1))
    print()
    print("  ek oran: reklamsız +%.0f%% … +%.0f%%, reklamlı +%.0f%% … +%.0f%%" % (
        min(no_ads), max(no_ads), min(with_ads), max(with_ads)))
    print()


def main():
    print("Görev tavanı: 7 × %d + %d = %d Hamur / hafta" % (
        sum(r for _, _, r in DAILY_MISSIONS), sum(r for _, _, r in WEEKLY_MISSIONS), MAX_PER_WEEK))
    print()
    table(False)
    table(True)


if __name__ == "__main__":
    main()
