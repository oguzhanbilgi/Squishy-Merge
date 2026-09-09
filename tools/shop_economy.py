"""Sandik/magaza ekonomisi simulasyonu (GAME_DESIGN.md §5.2 ve §5.6).

Soru: mevcut sandik kurallari ve magaza fiyatlariyla oyuncu koleksiyonu ne
kadar surede tamamliyor, magaza gercekten devreye giriyor mu?

Bu dosya PRODUCTION DAVRANISINI MODELLER. Sabitler `scripts/game/` altindaki
GDScript degerlerinden birebir kopyalanmistir; oradaki bir deger degisirse
BURASI DA DEGISMELI (her sabitin yaninda kaynagi yazili).

SANDIK MODELI (chest_system.gd ile ayni, iki asamali):

  1) RARITY rulesi   : Common %60 / Rare %25 / Epic %12 / Legendary %3
  2) ODUL TIPI rulesi: %30 skin / %70 Hamur

  Bu ikisi BAGIMSIZ. Rarity sandigin kalitesini secer; odul tipi o kalitede
  skin mi Hamur mi cikacagini secer. Legendary bir sandik da %70 olasilikla
  Hamur verir (ama 150 Hamur).

  Skin cikarsa: o rarity'de oyuncunun SAHIP OLMADIGI skinlerden biri secilir.
  Acilmamis skin kalmadiysa ayni rarity'nin Hamur karsiligina dusulur.
  Bir sandik asla hem skin hem Hamur vermez.

GELIR KAYNAKLARI:
  - gunluk giris   : 15 Hamur/gun
  - sandik (Hamur) : 10 / 25 / 60 / 150 (rarity'e gore)
  - teselli odulu  : 5 Hamur (kaybedilen round)
  - sandik sayisi  : level kazanildiginda 1, ayrica her 75 merge'de 1

Kullanim:  python tools/shop_economy.py
"""
import random

# --- Sabitler: GDScript'teki degerlerle ayni tutulmali ---

PRICES = [50, 150, 400, 900]           # scripts/game/shop.gd            PRICES
RARITY_DOUGH = [10, 25, 60, 150]       # scripts/game/chest_system.gd    RARITY_DOUGH
CONSOLATION = 5                        # scripts/game/chest_system.gd    CONSOLATION_DOUGH
RARITY_THRESHOLDS = [60, 85, 97, 100]  # scripts/game/chest_system.gd    RARITY_THRESHOLDS
SKIN_REWARD_PERCENT = 30               # scripts/game/chest_system.gd    SKIN_REWARD_PERCENT
MERGES_PER_CHEST = 75                  # scripts/game/chest_system.gd    MERGES_PER_BONUS_CHEST
DAILY = 15                             # scripts/game/daily_reward.gd    DAILY_DOUGH
SKIN_COUNTS = [8, 6, 4, 2]             # resources/skins/ icerigi (sayildi)

RARITY_NAMES = ["Common", "Rare", "Epic", "Legendary"]

# Level basina (merge medyani, kazanma orani).
#
# KAZANMA ORANLARI: L4-L10 icin GAME_DESIGN.md §3'teki kilitli tablo
# kullaniliyor (n=30, L8 icin n=60 ile olculmus, M8'de dondurulmus).
# L1-L3 §3'te yok; bu turda tools/bot_runner.gd ile n=30 olculdu.
#
# MERGE MEDYANLARI: hicbir dokumanda kayitli degildi, bu turda
# tools/bot_runner.gd ile n=30 olculdu (2026-09-09, mevcut kod).
#
# Eski tablo M8 zorluk ayarindan ONCEKI olcumlere dayaniyordu ve artik
# gecersizdi (orn. L10 %30 diyordu, guncel deger %43).
LEVELS = [
    # (merge medyani, kazanma orani)
    (2,  1.00),   # L1   kazanma olculdu 30/30
    (2,  1.00),   # L2   kazanma olculdu 30/30
    (7,  1.00),   # L3   kazanma olculdu 30/30
    (25, 0.97),   # L4   kazanma: GAME_DESIGN §3
    (21, 1.00),   # L5   kazanma: GAME_DESIGN §3
    (43, 1.00),   # L6   kazanma: GAME_DESIGN §3
    (45, 0.97),   # L7   kazanma: GAME_DESIGN §3
    (80, 0.70),   # L8   kazanma: GAME_DESIGN §3 (n=60)
    (78, 0.43),   # L9   kazanma: GAME_DESIGN §3
    (69, 0.43),   # L10  kazanma: GAME_DESIGN §3
]
# Sonsuz mod: kazanma/kaybetme yok, round merge uretir. Bu turda olculdu.
ENDLESS_MERGES = 179

DAYS = 30
CHECKPOINTS = [1, 7, 14, 30]
TRIALS = 5000

TOTAL_SKINS = sum(SKIN_COUNTS)


def roll_rarity():
    """chest_system.gd::roll_rarity ile ayni kumulatif esik mantigi."""
    roll = random.randint(1, RARITY_THRESHOLDS[-1])
    for index, threshold in enumerate(RARITY_THRESHOLDS):
        if roll <= threshold:
            return index
    return 0


def rolls_skin():
    """chest_system.gd::roll_wants_skin — %30 skin / %70 Hamur."""
    return random.randint(1, 100) <= SKIN_REWARD_PERCENT


class Player:
    def __init__(self, rounds_per_day):
        self.rounds = rounds_per_day
        self.dough = 0
        self.owned = [0, 0, 0, 0]      # rarity basina sahip olunan adet
        self.bought = [0, 0, 0, 0]     # bunlarin kaci magazadan alindi
        self.level = 0                 # sonraki oynanacak level indeksi
        self.merge_bank = 0
        self.chests = 0                # acilan toplam sandik
        self.skin_chests = 0           # bunlarin kaci gercekten skin verdi

    # --- Sandik ---

    def open_chest(self):
        """chest_system.gd::open ile ayni iki asamali akis."""
        self.chests += 1
        rarity = roll_rarity()
        if rolls_skin() and self.owned[rarity] < SKIN_COUNTS[rarity]:
            # Acilmamis skin havuzundan seciliyor: skin odulu gercekten
            # yeni bir skin aciyor.
            self.owned[rarity] += 1
            self.skin_chests += 1
        else:
            # Ya Hamur ruledi geldi ya da o rarity tamamlanmis.
            self.dough += RARITY_DOUGH[rarity]

    # --- Oynanis ---

    def play_round(self):
        if self.level < len(LEVELS):
            merges, win_rate = LEVELS[self.level]
            if random.random() < win_rate:
                self.open_chest()        # level tamamlama sandigi
                self.level += 1
            else:
                self.dough += CONSOLATION
        else:
            merges = ENDLESS_MERGES      # sonsuz modda kazanma/kaybetme yok
        self.merge_bank += merges
        while self.merge_bank >= MERGES_PER_CHEST:
            self.merge_bank -= MERGES_PER_CHEST
            self.open_chest()            # bonus sandik

    # --- Magaza ---

    def shop(self):
        """Tamamlayici oyuncu: parasi yettigi surece en ucuz eksigi alir.

        Bu bir UST SINIR modeli — magazanin ne kadar kullanilabildigini
        olcuyor. Gercek oyuncu sandiktan bedava gelebilecek bir skini
        beklemeyi secebilir.
        """
        while True:
            target = None
            for rarity in range(4):
                if (self.owned[rarity] < SKIN_COUNTS[rarity]
                        and self.dough >= PRICES[rarity]):
                    target = rarity
                    break
            if target is None:
                return
            self.dough -= PRICES[target]
            self.owned[target] += 1
            self.bought[target] += 1

    def day(self):
        self.dough += DAILY
        for _ in range(self.rounds):
            self.play_round()
        self.shop()


# --- Istatistik ---

def percentile(sorted_values, fraction):
    """Basit nearest-rank yuzdelik. numpy bagimliligi eklemeye deger degil."""
    if not sorted_values:
        return 0
    index = int(round(fraction * (len(sorted_values) - 1)))
    return sorted_values[index]


def simulate(rounds_per_day):
    snaps = {d: [] for d in CHECKPOINTS}
    complete_days = []
    for _ in range(TRIALS):
        player = Player(rounds_per_day)
        completed_on = None
        for day in range(1, DAYS + 1):
            player.day()
            if completed_on is None and sum(player.owned) == TOTAL_SKINS:
                completed_on = day
            if day in CHECKPOINTS:
                snaps[day].append((list(player.owned), list(player.bought),
                                   player.dough, player.chests,
                                   player.skin_chests))
        # Tamamlanmadiysa DAYS+1 ile isaretle — yuzdelik hesabi bozulmasin.
        complete_days.append(completed_on if completed_on else DAYS + 1)
    return snaps, complete_days


def report(label, rounds_per_day):
    snaps, complete_days = simulate(rounds_per_day)
    complete_days.sort()
    p25 = percentile(complete_days, 0.25)
    p50 = percentile(complete_days, 0.50)
    p75 = percentile(complete_days, 0.75)
    completed_ratio = sum(1 for d in complete_days if d <= DAYS) / len(complete_days)

    def fmt_day(value):
        return ("%d. gun" % value) if value <= DAYS else (">%d gun" % DAYS)

    print("")
    print("=== %s — %d round/gun (%d deneme) ===" % (label, rounds_per_day, TRIALS))
    print("koleksiyon 20/20 tamamlanma : p25 %s | medyan %s | p75 %s"
          % (fmt_day(p25), fmt_day(p50), fmt_day(p75)))
    print("30 gun icinde tamamlayan    : %%%.1f" % (100.0 * completed_ratio))
    print("")
    print("%-4s  %-28s  %-24s  %-11s  %s"
          % ("gun", "sahip C/R/E/L (toplam)", "magazadan C/R/E/L (top)",
             "kalan Hamur", "sandik (skin verdi)"))

    for day in CHECKPOINTS:
        rows = snaps[day]
        owned_cols = list(zip(*[r[0] for r in rows]))
        bought_cols = list(zip(*[r[1] for r in rows]))
        dough = sorted(r[2] for r in rows)
        chests = sorted(r[3] for r in rows)
        skin_chests = sorted(r[4] for r in rows)

        med = lambda values: percentile(sorted(values), 0.50)
        owned_med = [med(c) for c in owned_cols]
        bought_med = [med(c) for c in bought_cols]

        print("%-4d  %-28s  %-24s  %-11d  %d (%d)"
              % (day,
                 "%s (%d/20)" % ("/".join(str(v) for v in owned_med),
                                 sum(owned_med)),
                 "%s (%d)" % ("/".join(str(v) for v in bought_med),
                              sum(bought_med)),
                 percentile(dough, 0.50),
                 percentile(chests, 0.50),
                 percentile(skin_chests, 0.50)))


def main():
    print("SANDIK: rarity %s  |  odul tipi %%%d skin / %%%d Hamur"
          % ("/".join("%%%d" % p for p in
                      [RARITY_THRESHOLDS[0]] +
                      [RARITY_THRESHOLDS[i] - RARITY_THRESHOLDS[i - 1]
                       for i in range(1, 4)]),
             SKIN_REWARD_PERCENT, 100 - SKIN_REWARD_PERCENT))
    print("HAMUR  : sandik %s | gunluk %d | teselli %d"
          % ("/".join(str(d) for d in RARITY_DOUGH), DAILY, CONSOLATION))
    print("MAGAZA : %s" % " / ".join(
        "%s %d x%d" % (RARITY_NAMES[i], PRICES[i], SKIN_COUNTS[i])
        for i in range(4)))
    print("Koleksiyonun tamamini SATIN ALMAK: %d Hamur"
          % sum(SKIN_COUNTS[i] * PRICES[i] for i in range(4)))
    print("")
    print("NOT: Monte Carlo simulasyonu — sonuclar yaklasiktir ve her")
    print("     calistirmada birkac birim oynayabilir.")

    for label, rounds in (("KASUAL", 3), ("ORTA", 5), ("YOGUN", 10)):
        report(label, rounds)


if __name__ == "__main__":
    main()
