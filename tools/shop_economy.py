"""Ekonomi simulasyonu: sandik + skin magazasi + GUC magazasi.

Sorular:
  1) Mevcut sandik kurallari ve skin fiyatlariyla koleksiyon ne kadar surede
     tamamlaniyor, magaza gercekten devreye giriyor mu?  (M8.5-01)
  2) Guclerin Hamurla satilmasi gec oyun Hamur enflasyonunu emiyor mu, hangi
     fiyat seti dengeli?                                  (M8.5-05)

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

Kullanim:
  python tools/shop_economy.py            # production raporu
  python tools/shop_economy.py sweep      # fiyat taramasi + rewarded modelleri
  python tools/shop_economy.py packs      # gercek para pack taslagi olcumu
"""
import random
import sys

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

# --- Gucler (M8.5-05) ---

POWER_NAMES = ["Bomba", "Buyutucu", "Sarsinti", "Temizleyici"]
# scripts/game/power_up.gd  STARTER_COUNT — kayit basina TEK SEFER.
STARTER_COUNT = 1

# PRODUCTION FIYATLARI — scripts/game/power_up_economy.gd DOUGH_PRICES ile
# ayni tutulmali. Secim gerekcesi icin `python tools/shop_economy.py sweep`.
POWER_PRICES = [120, 180, 100, 160]

# =====================================================================
# VARSAYIMLAR (olculmus veri DEGIL) — gercek telemetry yok.
# Bunlarin hepsi ilk surum modelidir; gercek kullanim verisi gelince
# yeniden kalibre edilmeli.
# =====================================================================

# Bir round'da oyuncunun guc KULLANMAK ISTEME olasiligi.
#   dusuk : ~her 5-6 roundda 1
#   orta  : ~her 3-4 roundda 1
#   yuksek: ~her 2 roundda 1
CONSUMPTION_PROFILES = {
    "dusuk": 1.0 / 5.5,
    "orta": 1.0 / 3.5,
    "yuksek": 1.0 / 2.0,
}

# Guc ISTENME sikligi (hangisi daha sik kullanilir). Fiyattan AYRI bir
# kavram: sikligi ihtiyac belirler, fiyati gameplay degeri.
#   Sarsinti/Temizleyici sik: ikisi de "basim dertte" araci, durum bazli.
#   Bomba orta: hedefli, dusunerek kullaniliyor.
#   Buyutucu en az: oyuncular en degerli olani biriktirme egiliminde.
USAGE_WEIGHTS = [0.24, 0.20, 0.28, 0.28]

# Guc GAMEPLAY DEGERI (fiyat siralamasinin dayanagi), 1 = taban.
#   Sarsinti  0.85 : tek basina round kurtarmiyor, kaotik fayda
#   Bomba     1.00 : tek parca siler, ongorulebilir
#   Temizleyici 1.35: tum tier 1-2'yi siler, en guclu kurtarma
#   Buyutucu  1.50 : dogrudan level HEDEFINI karsilayabiliyor (GAME_DESIGN
#                    §10.3'teki tek istisna) — oyundaki en degerli tek etki
VALUE_MULTIPLIERS = [1.00, 1.50, 0.85, 1.35]

# Oyuncu gun sonu skin alisverisinde bu kadar Hamur'u guc icin ayirir.
# Aksi halde her gun butun parasini skine yatirip ertesi gun guc alamaz
# hale gelirdi; gercek oyuncu boyle davranmaz.
POWER_RESERVE_POWERS = 2

# Level basina (merge medyani, kazanma orani).
#
# KAZANMA ORANLARI: L4-L10 icin GAME_DESIGN.md §3'teki kilitli tablo
# kullaniliyor (n=30, L8 icin n=60 ile olculmus, M8'de dondurulmus).
# L1-L3 §3'te yok; M8.5-01 turunda tools/bot_runner.gd ile n=30 olculdu.
#
# MERGE MEDYANLARI: M8.5-01 turunda tools/bot_runner.gd ile n=30 olculdu.
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
# Sonsuz mod: kazanma/kaybetme yok, round merge uretir. M8.5-01'de olculdu.
ENDLESS_MERGES = 179

DAYS = 90
CHECKPOINTS = [1, 7, 14, 30, 60, 90]
TRIALS = 4000
# Fiyat taramasi kiyaslama amacli; daha az deneme yeterli.
SWEEP_TRIALS = 1200

TOTAL_SKINS = sum(SKIN_COUNTS)


# --- Rewarded refill modelleri (M8.5-05 §6) ---
#
# ONEMLI: revive reklamlari (GAME_DESIGN §11) BURAYA SAYILMAZ. Revive guc
# envanteri VERMEZ; bu tamamen ayri bir rewarded akisidir.
class Rewarded:
    """Rewarded guc refill politikasi.

    per_round : round basina toplam refill hakki (Model A)
    per_type  : True ise hak HER GUC TIPI icin ayri (Model B)
    per_day   : gunluk ust sinir (None = sinirsiz)
    """

    def __init__(self, label, per_round=0, per_type=False, per_day=None):
        self.label = label
        self.per_round = per_round
        self.per_type = per_type
        self.per_day = per_day


REWARDED_OFF = Rewarded("rewarded yok")
# Task §5: gunluk 0/1/2 refill senaryolari.
REWARDED_DAY = [
    Rewarded("0 rewarded/gun"),
    Rewarded("1 rewarded/gun", per_round=1, per_day=1),
    Rewarded("2 rewarded/gun", per_round=1, per_day=2),
]
# ONERILEN production capi (M8.5-05 raporu): round basina DEGIL GUN basina.
# Round basina 1 refill bile Hamur guc magazasini tamamen olduruyor (yogun
# oyuncuda 0 guc satin aliniyor, 90. gun Hamur'u 50.000'e geri donuyor).
RECOMMENDED_REWARDED = Rewarded("ONERILEN: 1 rewarded/gun",
                                per_round=1, per_day=1)
# Task §6: Model A vs Model B.
REWARDED_MODELS = [
    Rewarded("Model A: 1/round (toplam)", per_round=1),
    Rewarded("Model B: 1/round HER TIP", per_round=1, per_type=True),
]


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


def pick_power():
    """USAGE_WEIGHTS'e gore bir guc tipi secer."""
    roll = random.random()
    total = 0.0
    for index, weight in enumerate(USAGE_WEIGHTS):
        total += weight
        if roll <= total:
            return index
    return len(USAGE_WEIGHTS) - 1


class Player:
    def __init__(self, rounds_per_day, want_rate=0.0,
                 power_prices=None, rewarded=REWARDED_OFF):
        self.rounds = rounds_per_day
        self.want_rate = want_rate
        self.power_prices = power_prices or POWER_PRICES
        self.rewarded = rewarded

        self.dough = 0
        self.owned = [0, 0, 0, 0]      # rarity basina sahip olunan adet
        self.bought = [0, 0, 0, 0]     # bunlarin kaci magazadan alindi
        self.level = 0                 # sonraki oynanacak level indeksi
        self.merge_bank = 0
        self.chests = 0                # acilan toplam sandik
        self.skin_chests = 0           # bunlarin kaci gercekten skin verdi

        # Guc envanteri: baslangic hediyesi KAYIT BASINA BIR KEZ.
        self.inventory = [STARTER_COUNT] * 4
        self.powers_bought = [0, 0, 0, 0]
        self.powers_used = [0, 0, 0, 0]
        self.powers_rewarded = [0, 0, 0, 0]
        self.powers_unmet = 0          # istedi ama ne stok ne reklam ne para
        self.dough_on_skins = 0
        self.dough_on_powers = 0
        self.ads_watched = 0

        self._day_ads = 0

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

    # --- Gucler ---

    def _rewarded_budget(self, round_ads, round_type_ads, kind):
        """Bu round'da bu tip icin rewarded refill hakki var mi?"""
        rw = self.rewarded
        if rw.per_round <= 0:
            return False
        if rw.per_day is not None and self._day_ads >= rw.per_day:
            return False
        if rw.per_type:
            return round_type_ads[kind] < rw.per_round
        return round_ads[0] < rw.per_round

    def use_powers_in_round(self, round_ads, round_type_ads):
        """Oyuncu bu round'da guc kullanmak isterse edinme zincirini isletir.

        want_rate 1.0'dan buyuk olabilir: tam sayi kismi kadar KESIN istek,
        kalan kesir olasilikli. Model A / Model B farki ancak round basina
        BIRDEN FAZLA guc istenince ortaya cikiyor (bkz. rewarded_study).
        """
        if self.want_rate <= 0.0:
            return
        wants = int(self.want_rate)
        if random.random() < self.want_rate - wants:
            wants += 1
        for _ in range(wants):
            self._resolve_one_want(round_ads, round_type_ads)

    def _resolve_one_want(self, round_ads, round_type_ads):
        """Tek bir guc istegi.

        Sira: (1) stok, (2) rewarded reklam, (3) Hamurla satin alma.
        Reklam paradan ONCE geliyor cunku bedava — bu, Hamur magazasi
        acisindan EN KOTU durum ve olcmek istedigimiz sey tam olarak bu.
        """
        kind = pick_power()

        if self.inventory[kind] > 0:
            self.inventory[kind] -= 1
            self.powers_used[kind] += 1
            return

        if self._rewarded_budget(round_ads, round_type_ads, kind):
            round_ads[0] += 1
            round_type_ads[kind] += 1
            self._day_ads += 1
            self.ads_watched += 1
            self.powers_rewarded[kind] += 1
            self.powers_used[kind] += 1
            return

        price = self.power_prices[kind]
        if self.dough >= price:
            self.dough -= price
            self.dough_on_powers += price
            self.powers_bought[kind] += 1
            self.powers_used[kind] += 1
            return

        self.powers_unmet += 1

    # --- Oynanis ---

    def play_round(self):
        round_ads = [0]
        round_type_ads = [0, 0, 0, 0]
        self.use_powers_in_round(round_ads, round_type_ads)

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

    def _power_reserve(self):
        """Guc icin ayrilan Hamur: ~2 gucun ortalama fiyati."""
        if self.want_rate <= 0.0:
            return 0
        mean_price = sum(self.power_prices) / 4.0
        return int(POWER_RESERVE_POWERS * mean_price)

    def shop(self):
        """Tamamlayici oyuncu: parasi yettigi surece en ucuz eksigi alir.

        Bu bir UST SINIR modeli — magazanin ne kadar kullanilabildigini
        olcuyor. Gercek oyuncu sandiktan bedava gelebilecek bir skini
        beklemeyi secebilir.

        M8.5-05: guc rezervi dusulduktan SONRA harcanir. Skin ve guc ayni
        cuzdandan beslendigi icin asil olcmek istedigimiz sey bu rekabet.
        """
        reserve = self._power_reserve()
        while True:
            target = None
            for rarity in range(4):
                if (self.owned[rarity] < SKIN_COUNTS[rarity]
                        and self.dough - reserve >= PRICES[rarity]):
                    target = rarity
                    break
            if target is None:
                return
            self.dough -= PRICES[target]
            self.dough_on_skins += PRICES[target]
            self.owned[target] += 1
            self.bought[target] += 1

    def day(self):
        self._day_ads = 0
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


def med(values):
    return percentile(sorted(values), 0.50)


def simulate(rounds_per_day, want_rate=0.0, power_prices=None,
             rewarded=REWARDED_OFF, trials=TRIALS, days=DAYS,
             checkpoints=None):
    checkpoints = checkpoints or CHECKPOINTS
    snaps = {d: [] for d in checkpoints}
    complete_days = []
    for _ in range(trials):
        player = Player(rounds_per_day, want_rate, power_prices, rewarded)
        completed_on = None
        for day in range(1, days + 1):
            player.day()
            if completed_on is None and sum(player.owned) == TOTAL_SKINS:
                completed_on = day
            if day in checkpoints:
                snaps[day].append({
                    "owned": list(player.owned),
                    "bought": list(player.bought),
                    "dough": player.dough,
                    "chests": player.chests,
                    "skin_chests": player.skin_chests,
                    "inventory": sum(player.inventory),
                    "p_bought": sum(player.powers_bought),
                    "p_used": sum(player.powers_used),
                    "p_rewarded": sum(player.powers_rewarded),
                    "p_unmet": player.powers_unmet,
                    "d_skins": player.dough_on_skins,
                    "d_powers": player.dough_on_powers,
                    "ads": player.ads_watched,
                })
        # Tamamlanmadiysa days+1 ile isaretle — yuzdelik hesabi bozulmasin.
        complete_days.append(completed_on if completed_on else days + 1)
    return snaps, complete_days


def summarize(snaps, complete_days, days=DAYS):
    """Checkpoint basina medyan/p25/p75 ozeti."""
    out = {}
    for day, rows in snaps.items():
        dough = sorted(r["dough"] for r in rows)
        out[day] = {
            "dough_p25": percentile(dough, 0.25),
            "dough_p50": percentile(dough, 0.50),
            "dough_p75": percentile(dough, 0.75),
            "owned": med([sum(r["owned"]) for r in rows]),
            "bought": med([sum(r["bought"]) for r in rows]),
            "inventory": med([r["inventory"] for r in rows]),
            "p_bought": med([r["p_bought"] for r in rows]),
            "p_used": med([r["p_used"] for r in rows]),
            "p_rewarded": med([r["p_rewarded"] for r in rows]),
            "p_unmet": med([r["p_unmet"] for r in rows]),
            "d_skins": med([r["d_skins"] for r in rows]),
            "d_powers": med([r["d_powers"] for r in rows]),
            "ads": med([r["ads"] for r in rows]),
        }
    cd = sorted(complete_days)
    out["complete"] = {
        "p25": percentile(cd, 0.25),
        "p50": percentile(cd, 0.50),
        "p75": percentile(cd, 0.75),
        "ratio30": sum(1 for d in cd if d <= 30) / len(cd),
    }
    return out


def fmt_day(value, days=DAYS):
    return ("%d. gun" % value) if value <= days else (">%d gun" % days)


# =====================================================================
# 1) Production raporu
# =====================================================================

def report(label, rounds_per_day, profile_name, want_rate,
           rewarded=REWARDED_OFF, trials=TRIALS):
    snaps, complete_days = simulate(rounds_per_day, want_rate, POWER_PRICES,
                                    rewarded, trials)
    s = summarize(snaps, complete_days)
    c = s["complete"]

    print("")
    print("=== %s — %d round/gun | guc kullanimi: %s | %s (%d deneme) ==="
          % (label, rounds_per_day, profile_name, rewarded.label, trials))
    print("koleksiyon 20/20 : p25 %s | medyan %s | p75 %s   (30 gun icinde %%%.1f)"
          % (fmt_day(c["p25"]), fmt_day(c["p50"]), fmt_day(c["p75"]),
             100.0 * c["ratio30"]))
    print("")
    print("%-4s  %-24s  %-7s  %-8s  %-7s  %-6s  %-6s  %-6s  %s"
          % ("gun", "Hamur p25/med/p75", "skin", "alinan", "guc al", "kull.",
             "rekl.", "stok", "Hamur: skin / guc"))
    for day in CHECKPOINTS:
        r = s[day]
        print("%-4d  %-24s  %-7s  %-8d  %-7d  %-6d  %-6d  %-6d  %d / %d"
              % (day,
                 "%d / %d / %d" % (r["dough_p25"], r["dough_p50"], r["dough_p75"]),
                 "%d/20" % r["owned"], r["bought"], r["p_bought"], r["p_used"],
                 r["p_rewarded"], r["inventory"], r["d_skins"], r["d_powers"]))
    return s


# =====================================================================
# 2) Fiyat taramasi
# =====================================================================

def price_set(base):
    """Deger carpanlarindan fiyat seti uretir, 10'a yuvarlar."""
    return [int(round(base * m / 10.0) * 10) for m in VALUE_MULTIPLIERS]


def sweep():
    print("=" * 78)
    print("FIYAT TARAMASI — hangi taban fiyat dengeli?")
    print("=" * 78)
    print("")
    print("Fiyat SEKLI deger carpanlarindan turetiliyor (assumption):")
    for i, name in enumerate(POWER_NAMES):
        print("  %-12s x%.2f  (kullanim agirligi %.2f)"
              % (name, VALUE_MULTIPLIERS[i], USAGE_WEIGHTS[i]))
    print("")
    print("Referans: guc sink'i YOKKEN 30. gun Hamur medyani")
    for rounds, prof in ((3, "dusuk"), (5, "orta"), (10, "yuksek")):
        snaps, cd = simulate(rounds, 0.0, None, REWARDED_OFF, SWEEP_TRIALS)
        s = summarize(snaps, cd)
        print("  %2d round/gun : gun30 %6d | gun90 %6d | koleksiyon medyan %s"
              % (rounds, s[30]["dough_p50"], s[90]["dough_p50"],
                 fmt_day(s["complete"]["p50"])))

    print("")
    print("--- SEKIL KIYASI (taban 130): duz fiyat vs deger-agirlikli ---")
    flat = [130, 130, 130, 130]
    weighted = price_set(130)
    for name, prices in (("duz       %s" % flat, flat),
                         ("agirlikli %s" % weighted, weighted)):
        snaps, cd = simulate(10, CONSUMPTION_PROFILES["yuksek"], prices,
                             REWARDED_OFF, SWEEP_TRIALS)
        s = summarize(snaps, cd)
        used = [0, 0, 0, 0]
        print("  %-28s gun30 Hamur %5d | guc alindi %3d | karsilanmayan %d"
              % (name, s[30]["dough_p50"], s[30]["p_bought"], s[30]["p_unmet"]))

    print("")
    for rounds, prof_name in ((3, "dusuk"), (5, "orta"), (10, "yuksek")):
        want = CONSUMPTION_PROFILES[prof_name]
        print("--- %d round/gun | guc kullanimi %s ---" % (rounds, prof_name))
        print("%-22s  %-8s  %-8s  %-9s  %-9s  %-8s  %s"
              % ("fiyat seti", "gun30", "gun90", "koleksiyon", "guc al/30g",
                 "karsilnm", "Hamur guce"))
        for base in (80, 100, 120, 140, 160, 180, 200):
            prices = price_set(base)
            snaps, cd = simulate(rounds, want, prices, REWARDED_OFF,
                                 SWEEP_TRIALS)
            s = summarize(snaps, cd)
            print("%-22s  %-8d  %-8d  %-9s  %-9d  %-8d  %d"
                  % (str(prices), s[30]["dough_p50"], s[90]["dough_p50"],
                     fmt_day(s["complete"]["p50"]), s[30]["p_bought"],
                     s[30]["p_unmet"], s[30]["d_powers"]))
        print("")

    print("--- ADAY FIYATLARIN YAKIN KIYASI (gun 7 = ilk hafta hissi) ---")
    print("%-22s  %-6s  %-9s  %-9s  %-9s  %-9s  %-9s  %s"
          % ("fiyat seti", "round", "gun7 H.", "gun7 guc", "gun30 H.",
             "gun90 H.", "koleksiyon", "karsilanmayan/30g"))
    for base in (100, 110, 120, 130):
        prices = price_set(base)
        for rounds, prof_name in ((3, "dusuk"), (5, "orta"), (10, "yuksek")):
            want = CONSUMPTION_PROFILES[prof_name]
            snaps, cd = simulate(rounds, want, prices, REWARDED_OFF,
                                 SWEEP_TRIALS)
            s = summarize(snaps, cd)
            print("%-22s  %-6d  %-9d  %-9d  %-9d  %-9d  %-9s  %d"
                  % (str(prices) if rounds == 3 else "", rounds,
                     s[7]["dough_p50"], s[7]["p_bought"], s[30]["dough_p50"],
                     s[90]["dough_p50"], fmt_day(s["complete"]["p50"]),
                     s[30]["p_unmet"]))
        print("")

    rewarded_study()


def rewarded_study():
    print("=" * 78)
    print("REWARDED REFILL — gunluk cap ve Model A / Model B")
    print("=" * 78)
    print("NOT: revive reklamlari (GAME_DESIGN §11) BURAYA SAYILMAZ.")
    print("     Revive guc envanteri VERMEZ, tamamen ayri bir akistir.")
    print("")
    print("%-26s  %-6s  %-9s  %-9s  %-9s  %-9s  %s"
          % ("senaryo", "round", "gun30 H.", "guc ALDI", "guc BEDAVA",
             "reklam/gun", "Hamur guce"))
    for rounds, prof_name in ((3, "dusuk"), (5, "orta"), (10, "yuksek")):
        want = CONSUMPTION_PROFILES[prof_name]
        for rw in REWARDED_DAY + REWARDED_MODELS:
            snaps, cd = simulate(rounds, want, POWER_PRICES, rw, SWEEP_TRIALS)
            s = summarize(snaps, cd)
            ads30 = s[30]["ads"]
            print("%-26s  %-6d  %-9d  %-9d  %-9d  %-9.2f  %d"
                  % (rw.label, rounds, s[30]["dough_p50"], s[30]["p_bought"],
                     s[30]["p_rewarded"], ads30 / 30.0, s[30]["d_powers"]))
        print("")

    # --- Model A vs B ancak SPAM altinda ayrisiyor ---
    #
    # Normal profillerde oyuncu round basina ~0.5 guc istiyor, yani Model
    # B'nin fazladan kapasitesi HIC kullanilmiyor ve iki model ayni sonucu
    # veriyor. Fark yalnizca round basina birden fazla guc isteyen (spam
    # egilimli) oyuncuda ortaya cikiyor — asil risk de o.
    print("--- SPAM STRES TESTI: round basina 2 guc isteyen oyuncu ---")
    print("%-26s  %-6s  %-9s  %-10s  %-11s  %-11s  %s"
          % ("senaryo", "round", "gun30 H.", "guc BEDAVA", "guc/round",
             "reklam/gun", "Hamur guce"))
    for rounds in (5, 10):
        for rw in [REWARDED_OFF] + REWARDED_MODELS + [
                Rewarded("Model A + 1/gun cap", per_round=1, per_day=1),
                Rewarded("Model A + 3/gun cap", per_round=1, per_day=3)]:
            snaps, cd = simulate(rounds, 2.0, POWER_PRICES, rw, SWEEP_TRIALS)
            s = summarize(snaps, cd)
            used30 = s[30]["p_used"]
            print("%-26s  %-6d  %-9d  %-10d  %-11.2f  %-11.2f  %d"
                  % (rw.label, rounds, s[30]["dough_p50"], s[30]["p_rewarded"],
                     used30 / (30.0 * rounds), s[30]["ads"] / 30.0,
                     s[30]["d_powers"]))
        print("")


# =====================================================================
# 3) Gercek para Power Pack taslagi (SADECE OLCUM — billing YOK)
# =====================================================================

# ONERILEN icerik (her gucten kac adet). Ilk taslak x2/x5/x12 idi; olcum
# sonrasi x3/x6/x12'ye cekildi:
#   - x2 Mini yogun oyuncunun 2.1 gunluk Hamur gelirine denk geliyordu, yani
#     satin alma islemine degmeyecek kadar kucuktu. x3 -> 3.1 gun.
#   - x5 -> x6 ile ladder temiz bir 1:2:4 oluyor (3 / 6 / 12 gunluk gelir).
#   - x12 Mega korundu: 96 round'luk stok, yogun oyuncuda ~10 gun. Ustu
#     gating'i tamamen anlamsizlastirirdi.
PACK_DRAFTS = [
    ("Mini Pack", 3),
    ("Power Pack", 6),
    ("Mega Pack", 12),
]


def packs():
    print("=" * 78)
    print("GERCEK PARA POWER PACK TASLAGI — sadece olcum")
    print("=" * 78)
    print("BILLING KURULMADI. TL/USD fiyat YOK, product ID YOK.")
    print("Olculen sey: pack icerigi Hamur cinsinden ne kadar eder ve")
    print("oyuncunun kac gunluk Hamur gelirine denk gelir.")
    print("")

    pack_dough = {}
    for name, per_power in PACK_DRAFTS:
        value = sum(POWER_PRICES) * per_power
        pack_dough[name] = value
        print("  %-12s her gucten x%-3d = %d guc | Hamur degeri %d"
              % (name, per_power, per_power * 4, value))

    print("")
    print("Gunluk Hamur GELIRI (harcama oncesi, guc sink'i acikken):")
    income = {}
    for rounds, prof_name in ((3, "dusuk"), (5, "orta"), (10, "yuksek")):
        want = CONSUMPTION_PROFILES[prof_name]
        snaps, cd = simulate(rounds, want, POWER_PRICES, REWARDED_OFF,
                             SWEEP_TRIALS, days=30, checkpoints=[30])
        s = summarize(snaps, cd, days=30)
        r = s[30]
        total = r["dough_p50"] + r["d_skins"] + r["d_powers"]
        per_day = total / 30.0
        income[rounds] = per_day
        print("  %2d round/gun : ~%d Hamur/gun (30 gunde toplam ~%d)"
              % (rounds, int(per_day), int(total)))

    print("")
    print("%-12s  %-10s  %-14s  %-14s  %s"
          % ("pack", "Hamur", "3 r/gun", "5 r/gun", "10 r/gun"))
    for name, _ in PACK_DRAFTS:
        value = pack_dough[name]
        print("%-12s  %-10d  %-14s  %-14s  %s"
              % (name, value,
                 "%.1f gunluk" % (value / income[3]),
                 "%.1f gunluk" % (value / income[5]),
                 "%.1f gunluk" % (value / income[10])))

    print("")
    print("Pack kac round'luk guc kullanimina yeter (yuksek profil, ~0.5/round):")
    for name, per_power in PACK_DRAFTS:
        count = per_power * 4
        print("  %-12s %3d guc  -> ~%d round" % (name, count, int(count / 0.5)))


# =====================================================================

def header():
    print("SANDIK: rarity %s  |  odul tipi %%%d skin / %%%d Hamur"
          % ("/".join("%%%d" % p for p in
                      [RARITY_THRESHOLDS[0]] +
                      [RARITY_THRESHOLDS[i] - RARITY_THRESHOLDS[i - 1]
                       for i in range(1, 4)]),
             SKIN_REWARD_PERCENT, 100 - SKIN_REWARD_PERCENT))
    print("HAMUR  : sandik %s | gunluk %d | teselli %d"
          % ("/".join(str(d) for d in RARITY_DOUGH), DAILY, CONSOLATION))
    print("SKIN   : %s" % " / ".join(
        "%s %d x%d" % (RARITY_NAMES[i], PRICES[i], SKIN_COUNTS[i])
        for i in range(4)))
    print("GUC    : %s" % " / ".join(
        "%s %d" % (POWER_NAMES[i], POWER_PRICES[i]) for i in range(4)))
    print("Koleksiyonun tamamini SATIN ALMAK: %d Hamur"
          % sum(SKIN_COUNTS[i] * PRICES[i] for i in range(4)))
    print("")
    print("NOT: Monte Carlo simulasyonu — sonuclar yaklasiktir ve her")
    print("     calistirmada birkac birim oynayabilir.")
    print("NOT: guc kullanim sikliklari OLCULMUS DEGIL, varsayim (telemetry")
    print("     yok). Gercek veri gelince yeniden kalibre edilmeli.")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "report"
    if mode == "sweep":
        sweep()
        return
    if mode == "packs":
        packs()
        return

    header()
    # Guc sink'i OLMADAN referans (M8.5-01 ile kiyaslanabilir kalsin).
    print("")
    print("#" * 78)
    print("# A) GUC SINK'I YOK — M8.5-01 referansi")
    print("#" * 78)
    for label, rounds in (("KASUAL", 3), ("ORTA", 5), ("YOGUN", 10)):
        report(label, rounds, "yok (referans)", 0.0)

    print("")
    print("#" * 78)
    print("# B) GUC SINK'I ACIK — production fiyatlari, rewarded YOK")
    print("#" * 78)
    for label, rounds, prof in (("KASUAL", 3, "dusuk"), ("ORTA", 5, "orta"),
                                ("YOGUN", 10, "yuksek")):
        report(label, rounds, prof, CONSUMPTION_PROFILES[prof])

    print("")
    print("#" * 78)
    print("# C) GUC SINK'I + ONERILEN REWARDED CAP (1 refill/GUN)")
    print("#" * 78)
    for label, rounds, prof in (("KASUAL", 3, "dusuk"), ("ORTA", 5, "orta"),
                                ("YOGUN", 10, "yuksek")):
        report(label, rounds, prof, CONSUMPTION_PROFILES[prof],
               RECOMMENDED_REWARDED)


if __name__ == "__main__":
    main()
