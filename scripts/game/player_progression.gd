class_name PlayerProgression
extends RefCounted
## Oyuncu Seviyesi + XP (TASK/045) — SAF hesap katmanı. Kayda YAZMAZ, kayıttan
## OKUMAZ; kalıcılık ve doğrulanmış mutasyon SaveManager'da, ekran okuması
## PlayerProfile'da. Testler bu dosyayı doğrudan sınar.
##
##   Kaynak     `player_xp` — KÜMÜLATİF XP, tek gerçek. Seviye SAKLANMAZ: her okumada
##              XP'den türetilir; kayıt ile seviye asla ayrışamaz.
##   Eğri       seviye L → L+1 gereksinimi = min(400, 60 + 20·(L−1)): 60, 80, 100 …
##              380, sonra hep 400. Tavan GEREKSİNİMDE; seviyenin tavanı YOK.
##   Kaynaklar  yalnız round KESİN bitince (Main._on_round_finished → SaveManager.
##              record_round_finished, round başına tam bir kez):
##                +1   o round'daki her gerçek merge (GameState.merge_count)
##                +20  sabit level BAŞARIYLA bitti (tekrar oynanış dahil; kayıp / sonsuz yok)
##                +10  önceki en iyiye göre her YENİ kalıcı yıldız (tekrar ödüllendirilmez)
##              Skor, güç / Büyütücü, sandık, koleksiyon, Mağaza, Hamur, reklam, günlük
##              ödül, ekran açmak XP VERMEZ.
##   Göç        TASK/045 öncesi kayıt: bootstrap = toplam merge + 10·yıldız + 20·tamamlanan
##              level — kayıtta ZATEN duran gerçekler, aynı ağırlıklarla. Geçmiş round,
##              skor ya da güç kullanımı UYDURULMAZ.

const XP_BASE: int = 60
const XP_STEP: int = 20
## Seviye başına gereksinimin tavanı (seviye değil).
const XP_REQUIREMENT_CAP: int = 400
## Gereksinimin tavana ulaştığı ilk seviye: 60 + 20·(L−1) ≥ 400 → L = 18.
const CAP_LEVEL: int = 1 + (XP_REQUIREMENT_CAP - XP_BASE + XP_STEP - 1) / XP_STEP
## CAP_LEVEL'e ulaşmak için gereken kümülatif XP (60 + 80 + … + 380 = 3740).
const XP_AT_CAP_LEVEL: int = XP_BASE * (CAP_LEVEL - 1) + XP_STEP * (CAP_LEVEL - 1) * (CAP_LEVEL - 2) / 2

const XP_PER_MERGE: int = 1
const XP_LEVEL_CLEAR: int = 20
const XP_PER_NEW_STAR: int = 10
const STARS_PER_LEVEL: int = 3

## Bozukluk sınırı — tasarım tavanı DEĞİL: 1 milyar XP ≈ saniyede bir merge ile 30+ yıl
## kesintisiz oyun. Kayıttaki daha büyük (ya da negatif / metin / NaN) değer GEÇERSİZ
## sayılır ve SaveManager onu kayıttaki gerçeklerden kurtarır; ödüller bu sınırda durur
## (int taşması yok). Bu sınırda seviye ~2,5 milyon — pratikte ulaşılamaz.
const MAX_XP: int = 1_000_000_000


# --- Eğri ----------------------------------------------------------------------

## `level` seviyesinden bir sonrakine geçmek için gereken XP (1 → 2: 60).
static func xp_to_next(level: int) -> int:
	var at: int = maxi(level, 1)
	if at >= CAP_LEVEL:
		return XP_REQUIREMENT_CAP
	return mini(XP_REQUIREMENT_CAP, XP_BASE + XP_STEP * (at - 1))


## `level` seviyesinin BAŞLADIĞI kümülatif XP (seviye 1 = 0, seviye 2 = 60, 3 = 140).
## Kapalı form: döngü yok, saçma büyük seviyede de sabit süre.
static func total_xp_for_level(level: int) -> int:
	var at: int = maxi(level, 1)
	if at <= CAP_LEVEL:
		var steps: int = at - 1
		return XP_BASE * steps + XP_STEP * steps * (steps - 1) / 2
	return XP_AT_CAP_LEVEL + XP_REQUIREMENT_CAP * (at - CAP_LEVEL)


## Kümülatif XP → seviye (0 XP = seviye 1). Geçersiz / negatif XP 0 sayılır.
static func level_for_xp(xp: int) -> int:
	var total: int = clamp_xp(xp)
	if total >= XP_AT_CAP_LEVEL:
		return CAP_LEVEL + (total - XP_AT_CAP_LEVEL) / XP_REQUIREMENT_CAP
	var level: int = 1
	while level < CAP_LEVEL and total_xp_for_level(level + 1) <= total:
		level += 1
	return level


## Mevcut seviyenin içinde biriken XP (tam sınırda 0).
static func xp_into_level(xp: int) -> int:
	var total: int = clamp_xp(xp)
	return total - total_xp_for_level(level_for_xp(total))


## Mevcut seviyeden bir sonrakine gereken XP (ilerleme rayının paydası).
static func xp_required_for_next(xp: int) -> int:
	return xp_to_next(level_for_xp(xp))


## Ray oranı 0..1 (tam sınırda 0 — "0 / gereksinim").
static func level_ratio(xp: int) -> float:
	return float(xp_into_level(xp)) / float(maxi(xp_required_for_next(xp), 1))


# --- Doğrulama -------------------------------------------------------------------

## Kayıttaki ham XP değeri: geçerliyse 0..MAX_XP tamsayı, değilse -1 (çağıran
## kurtarır). JSON her sayıyı float okur; float int'e ÇEVRİLMEDEN önce sınanır
## (`int(1e300)` Godot'ta INT64_MIN verir). Metin, bool, null, dizi, NaN, sonsuz,
## negatif ve MAX_XP üstü GEÇERSİZ.
static func sanitize_xp(raw: Variant) -> int:
	match typeof(raw):
		TYPE_INT:
			var value: int = raw
			return value if value >= 0 and value <= MAX_XP else -1
		TYPE_FLOAT:
			var number: float = raw
			if is_nan(number) or is_inf(number) or number < 0.0 or number > float(MAX_XP):
				return -1
			return int(number)
	return -1


## Hesaplarda kullanılan güvenli aralık (0..MAX_XP).
static func clamp_xp(xp: int) -> int:
	return clampi(xp, 0, MAX_XP)


## Ödül ekleme: negatif ödül yok sayılır, sonuç MAX_XP'de durur (taşma yok).
static func add_xp(current: int, award: int) -> int:
	return mini(clamp_xp(current) + clampi(award, 0, MAX_XP), MAX_XP)


# --- Kaynaklar -------------------------------------------------------------------

## TASK/045 öncesi kayıt için tek seferlik XP: kayıttaki gerçekler, round ödülüyle
## AYNI ağırlıklarla (merge 1 · yıldız 10 · tamamlanan level 20). Örnek: 812 merge +
## 6 yıldız + 3 level = 812 + 60 + 60 = 932. Negatif girdiler 0 sayılır.
static func bootstrap_xp(total_merges: int, total_stars: int, completed_levels: int) -> int:
	var merges: int = clampi(total_merges, 0, MAX_XP)
	var stars: int = clampi(total_stars, 0, MAX_XP / XP_PER_NEW_STAR)
	var levels: int = clampi(completed_levels, 0, MAX_XP / XP_LEVEL_CLEAR)
	return add_xp(merges * XP_PER_MERGE + stars * XP_PER_NEW_STAR, levels * XP_LEVEL_CLEAR)


## Bitmiş bir round'un XP'si. `fixed_level_cleared`: sabit level BAŞARIYLA bitti
## (kayıp ve sonsuz mod false). Yıldız farkı yalnız temizlenen sabit level'da ve
## yalnız YENİ yıldızlar: önceki en iyi 2, yeni 3 → +10; 3 → 3 → 0 (0–3'e kırpılır).
static func round_xp_award(merges: int, fixed_level_cleared: bool, stars_before: int, stars_after: int) -> int:
	var award: int = clampi(merges, 0, MAX_XP) * XP_PER_MERGE
	if fixed_level_cleared:
		award += XP_LEVEL_CLEAR
		var gained: int = clampi(stars_after, 0, STARS_PER_LEVEL) - clampi(stars_before, 0, STARS_PER_LEVEL)
		award += XP_PER_NEW_STAR * maxi(gained, 0)
	return mini(award, MAX_XP)


## Sonuç ekranının kompakt ilerleme özeti (Main, round kesinleşince). Göç / geriye
## dönük açılışlar buraya GİRMEZ: önce/sonra aynı round'un kesinleştirmesinden.
##   xp_gained · xp_before · xp_after · level_before · level_after · levels_gained ·
##   new_achievements (katalog sırasıyla bu round'da açılanlar)
static func round_summary(xp_before: int, xp_after: int, achievements_before: Array,
		achievements_after: Array) -> Dictionary:
	var before: int = clamp_xp(xp_before)
	var after: int = maxi(clamp_xp(xp_after), before)
	var fresh: Array[StringName] = []
	for id in AchievementCatalog.ids():
		if achievements_after.has(id) and not achievements_before.has(id):
			fresh.append(id)
	return {
		"xp_gained": after - before,
		"xp_before": before,
		"xp_after": after,
		"level_before": level_for_xp(before),
		"level_after": level_for_xp(after),
		"levels_gained": level_for_xp(after) - level_for_xp(before),
		"new_achievements": fresh,
	}
