"""Magaza ekonomisi dengesi (GAME_DESIGN.md §5.6).\n\nSoru: mevcut Hamur gelir kaynaklariyla oyuncu fiyatlara ne kadar surede\nulasiyor? Tahmin etmek yerine simule ediliyor.\n\nGELIR KAYNAKLARI (hepsi mevcut, bu turda degistirilmedi):\n  - gunluk giris            : 15 Hamur/gun\n  - duplicate skin -> Hamur : 10 / 25 / 60 / 150 (rarity'e gore)\n  - teselli odulu           : 5 Hamur (kaybedilen round)\n  - sandiklar               : level kazanildiginda 1, ayrica her 75 merge'de 1\n\nSandiklar HEM gelir hem rakip: sahip olunmayan bir skin cikarsa skin BEDAVA\ngelir (magazadan almaya gerek kalmaz), sahip olunan cikarsa Hamur'a donusur.\nKoleksiyon doldukca sandiklar giderek Hamur uretecine donusuyor.\n\nMerge sayilari ve kazanma oranlari uydurma degil, tools/bot_runner.gd\nolcumlerinin medyanlari.\n\nKullanim:  python tools/shop_economy.py\n"""
import random

# --- Sabitler: koddaki degerlerle ayni tutulmali ---
PRICES = [50, 150, 400, 900]          # scripts/game/shop.gd PRICES
DUPLICATE_DOUGH = [10, 25, 60, 150]   # chest_system.gd DUPLICATE_DOUGH
CONSOLATION = 5                       # chest_system.gd CONSOLATION_DOUGH
DAILY = 15                            # daily_reward.gd DAILY_DOUGH
RARITY_THRESHOLDS = [60, 85, 97, 100] # chest_system.gd
MERGES_PER_CHEST = 75                 # chest_system.gd
SKIN_COUNTS = [8, 6, 4, 2]            # resources/skins/ icerigi

# Bot olcumlerinden (bag_L*.txt): merge medyani ve kazanma orani
LEVELS = [
    (2, 1.00), (3, 1.00), (7, 1.00), (22, 1.00), (21, 1.00),
    (47, 0.97), (43, 1.00), (79, 0.73), (77, 0.53), (65, 0.30),
]
ENDLESS_MERGES = 199

DAYS = 30
TRIALS = 3000


def roll_rarity():
    r = random.randint(1, 100)
    for i, t in enumerate(RARITY_THRESHOLDS):
        if r <= t:
            return i
    return 0


class Player:
    def __init__(self, rounds_per_day, skin_chance=1.0):
        self.rounds = rounds_per_day
        self.skin_chance = skin_chance
        self.dough = 0
        self.owned = [0, 0, 0, 0]      # rarity basina sahip olunan adet
        self.bought = [0, 0, 0, 0]     # bunlarin kaci magazadan alindi
        self.level = 0                 # sonraki oynanacak level indeksi
        self.merge_bank = 0

    def _open_chest(self):
        rarity = roll_rarity()
        # skin_chance: sandigin skin verme olasiligi. 1.0 = mevcut davranis
        # (acilmamis skin varsa HER ZAMAN skin verir).
        gives_skin = (self.owned[rarity] < SKIN_COUNTS[rarity]
                      and random.random() < self.skin_chance)
        if gives_skin:
            self.owned[rarity] += 1     # skin BEDAVA geldi
        else:
            self.dough += DUPLICATE_DOUGH[rarity]

    def play_round(self):
        if self.level < len(LEVELS):
            merges, win_rate = LEVELS[self.level]
            won = random.random() < win_rate
            if won:
                self._open_chest()       # level tamamlama sandigi
                self.level += 1
            else:
                self.dough += CONSOLATION
        else:
            merges = ENDLESS_MERGES      # sonsuz modda kazanma/kaybetme yok
        self.merge_bank += merges
        while self.merge_bank >= MERGES_PER_CHEST:
            self.merge_bank -= MERGES_PER_CHEST
            self._open_chest()           # bonus sandik

    def shop(self):
        """En ucuz eksik skin'i alabildigi surece alir (tamamlayici davranis)."""
        while True:
            best = None
            for r in range(4):
                if self.owned[r] < SKIN_COUNTS[r] and self.dough >= PRICES[r]:
                    best = r
                    break
            if best is None:
                return
            self.dough -= PRICES[best]
            self.owned[best] += 1
            self.bought[best] += 1

    def day(self):
        self.dough += DAILY
        for _ in range(self.rounds):
            self.play_round()
        self.shop()


def simulate(rounds_per_day, checkpoints, skin_chance=1.0):
    snaps = {d: [] for d in checkpoints}
    full_days = []
    for _ in range(TRIALS):
        p = Player(rounds_per_day, skin_chance)
        full_at = None
        for d in range(1, DAYS + 1):
            p.day()
            if full_at is None and sum(p.owned) == sum(SKIN_COUNTS):
                full_at = d
            if d in checkpoints:
                snaps[d].append((list(p.owned), list(p.bought), p.dough))
        full_days.append(full_at if full_at else DAYS + 1)
    return snaps, full_days


def report(label, rounds_per_day, checkpoints, skin_chance=1.0):
    snaps, full_days = simulate(rounds_per_day, checkpoints, skin_chance)
    full_days.sort()
    med_full = full_days[len(full_days) // 2]
    print("")
    print("=== %s (%d round/gun, sandik skin sansi %d%%, %d deneme) ===" % (
        label, rounds_per_day, int(100 * skin_chance), TRIALS))
    print("koleksiyon 20/20 medyan: %s" % (
        ("%d. gun" % med_full) if med_full <= DAYS else (">%d gun" % DAYS)))
    print("%-5s %-26s %-24s %s" % ("gun", "sahip (C/R/E/L)",
                                   "magazadan alinan", "kalan Hamur"))
    med = lambda xs: sorted(xs)[len(xs) // 2]
    for d in checkpoints:
        owned = list(zip(*[s[0] for s in snaps[d]]))
        bought = list(zip(*[s[1] for s in snaps[d]]))
        dough = [s[2] for s in snaps[d]]
        o = "/".join(str(med(c)) for c in owned)
        b = "/".join(str(med(c)) for c in bought)
        total_owned = sum(med(c) for c in owned)
        print("%-5d %-26s %-24s %d" % (
            d, "%s (toplam %d/20)" % (o, total_owned), b, med(dough)))


def main():
    print("Koleksiyonun tamami: %d Hamur" % sum(
        SKIN_COUNTS[i] * PRICES[i] for i in range(4)))
    print("Fiyatlar: Common %d / Rare %d / Epic %d / Legendary %d" % tuple(PRICES))

    print("\n########## MEVCUT DURUM (sandik acilmamis skini HER ZAMAN verir) ##########")
    for label, rounds in (("KASUAL", 3), ("ORTA", 5), ("YOGUN", 10)):
        report(label, rounds, [7, 14, 30])

    print("\n\n########## SECENEK B: sandik %30 olasilikla skin, kalani Hamur ##########")
    for label, rounds in (("KASUAL", 3), ("YOGUN", 10)):
        report(label, rounds, [7, 14, 30], skin_chance=0.30)

    print("\n\n########## SECENEK A: sandik SADECE Hamur verir, skin yalniz magazadan ##########")
    for label, rounds in (("KASUAL", 3), ("YOGUN", 10)):
        report(label, rounds, [7, 14, 30], skin_chance=0.0)


if __name__ == "__main__":
    main()
