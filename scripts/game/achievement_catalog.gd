class_name AchievementCatalog
extends RefCounted
## Başarımlar + unvanlar (TASK/045) — KİLİTLİ V1 kataloğu ve SAF değerlendirme.
## Kayda YAZMAZ, kayıttan OKUMAZ: istatistikler (`SaveManager.progression_stats()`)
## ve açık başarım listesi parametre olarak gelir.
##
##   Başarım    12 adet, kalıcı string id (kayıtta durur — değiştirilmez, yeniden
##              kullanılmaz). Kanonik istatistiğe bağlı eşik: toplam merge · kalıcı
##              yıldız (10 level × 3) · tamamlanan sabit level · sahip olunan katalog
##              Squishy'si. MONOTON: açılan asla kilitlenmez. Ödülü yalnız rozet /
##              açık durum + (bazılarında) UNVAN — Hamur, güç, sandık, reklam, gerçek
##              para ödülü YOK (ekonomi değişmedi).
##   Unvan      varsayılan "Birleştirici" her zaman açık; diğer 8 unvan YALNIZ
##              kendi başarımıyla açılır. Unvan açıkları SAKLANMAZ — açık başarım
##              listesinden türetilir. Yeni açılan unvan otomatik SEÇİLMEZ.
##
## Katalog sırası = oyuncuya gösterim sırası (kategori kategori).

const METRIC_MERGES: StringName = &"merges"
const METRIC_STARS: StringName = &"stars"
const METRIC_LEVELS: StringName = &"levels"
const METRIC_COLLECTION: StringName = &"collection"
const METRICS: Array[StringName] = [METRIC_MERGES, METRIC_STARS, METRIC_LEVELS, METRIC_COLLECTION]

const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": &"first_merge", "name": "İlk Squish", "description": "İlk birleşmeni yap.",
		"metric": METRIC_MERGES, "target": 1},
	{"id": &"merge_100", "name": "Hamur Isınıyor", "description": "Toplam 100 birleşme yap.",
		"metric": METRIC_MERGES, "target": 100},
	{"id": &"merge_500", "name": "Birleşme Ustası", "description": "Toplam 500 birleşme yap.",
		"metric": METRIC_MERGES, "target": 500},
	{"id": &"merge_1000", "name": "Bin Bir Squish", "description": "Toplam 1000 birleşme yap.",
		"metric": METRIC_MERGES, "target": 1000},
	{"id": &"stars_5", "name": "İlk Parıltılar", "description": "Toplam 5 yıldız kazan.",
		"metric": METRIC_STARS, "target": 5},
	{"id": &"stars_15", "name": "Yıldız Avcısı", "description": "Toplam 15 yıldız kazan.",
		"metric": METRIC_STARS, "target": 15},
	{"id": &"stars_30", "name": "Gökyüzü Tamam", "description": "30 yıldızın tamamını kazan.",
		"metric": METRIC_STARS, "target": 30},
	{"id": &"levels_3", "name": "Yolculuk Başlıyor", "description": "3 bölümü tamamla.",
		"metric": METRIC_LEVELS, "target": 3},
	{"id": &"levels_10", "name": "Harita Ustası", "description": "10 bölümün tamamını tamamla.",
		"metric": METRIC_LEVELS, "target": 10},
	{"id": &"collection_5", "name": "İlk Raf", "description": "5 Squishy keşfet.",
		"metric": METRIC_COLLECTION, "target": 5},
	{"id": &"collection_10", "name": "Koleksiyoncu", "description": "10 Squishy keşfet.",
		"metric": METRIC_COLLECTION, "target": 10},
	{"id": &"collection_20", "name": "Squishy Arşivcisi", "description": "20 Squishy'nin tamamını keşfet.",
		"metric": METRIC_COLLECTION, "target": 20},
]

const DEFAULT_TITLE: StringName = &"birlestirici"
## Sıra = unvan seçicinin sırası. `achievement`: unvanı açan TEK başarım (varsayılanda yok).
const TITLES: Array[Dictionary] = [
	{"id": DEFAULT_TITLE, "name": "Birleştirici", "achievement": &""},
	{"id": &"hamur_ustasi", "name": "Hamur Ustası", "achievement": &"merge_100"},
	{"id": &"birlesme_ustasi", "name": "Birleşme Ustası", "achievement": &"merge_500"},
	{"id": &"efsane_birlestirici", "name": "Efsane Birleştirici", "achievement": &"merge_1000"},
	{"id": &"yildiz_avcisi", "name": "Yıldız Avcısı", "achievement": &"stars_15"},
	{"id": &"yildiz_ustasi", "name": "Yıldız Ustası", "achievement": &"stars_30"},
	{"id": &"harita_ustasi", "name": "Harita Ustası", "achievement": &"levels_10"},
	{"id": &"koleksiyoncu", "name": "Koleksiyoncu", "achievement": &"collection_10"},
	{"id": &"squishy_arsivcisi", "name": "Squishy Arşivcisi", "achievement": &"collection_20"},
]


# --- Başarımlar ------------------------------------------------------------------

static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in ACHIEVEMENTS:
		out.append(entry["id"])
	return out


static func count() -> int:
	return ACHIEVEMENTS.size()


## Katalog girişi; bilinmeyen id boş sözlük.
static func find(id: StringName) -> Dictionary:
	for entry in ACHIEVEMENTS:
		if entry["id"] == id:
			return entry
	return {}


static func is_known(id: StringName) -> bool:
	return not find(id).is_empty()


## İstatistik sözlüğünden bir metriğin değeri (eksik / biçimsiz / negatif → 0).
static func metric_value(stats: Dictionary, metric: StringName) -> int:
	var raw: Variant = stats.get(metric, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return maxi(int(raw), 0)


## Başarımın ham ilerlemesi (hedefe kırpılmaz). Bilinmeyen id 0.
static func progress(id: StringName, stats: Dictionary) -> int:
	var entry: Dictionary = find(id)
	if entry.is_empty():
		return 0
	return metric_value(stats, entry["metric"])


static func target(id: StringName) -> int:
	var entry: Dictionary = find(id)
	return int(entry["target"]) if not entry.is_empty() else 0


## Kanonik istatistik hedefi karşılıyor mu (hedefte dahil).
static func is_satisfied(id: StringName, stats: Dictionary) -> bool:
	var entry: Dictionary = find(id)
	return not entry.is_empty() and metric_value(stats, entry["metric"]) >= int(entry["target"])


## Listeye EKLENECEK başarımlar (katalog sırası): istatistiğin desteklediği ama henüz
## `unlocked`'ta olmayanlar. Monoton: açık olan hiçbir id düşmez, tekrar dönmez.
static func newly_satisfied(stats: Dictionary, unlocked: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in ACHIEVEMENTS:
		var id: StringName = entry["id"]
		if not unlocked.has(id) and metric_value(stats, entry["metric"]) >= int(entry["target"]):
			out.append(id)
	return out


## Profil özeti için "sıradaki hedefler": her kategorinin İLK açılmamış başarımı,
## hedefe en yakın önce (oran), eşitlikte katalog sırası; en fazla `limit`. İlerleme
## değişmedikçe sıra değişmez; hepsi açıksa boş.
static func next_goals(stats: Dictionary, unlocked: Array, limit: int = 3) -> Array[StringName]:
	var candidates: Array[Dictionary] = []
	for metric in METRICS:
		for i in ACHIEVEMENTS.size():
			var entry: Dictionary = ACHIEVEMENTS[i]
			if entry["metric"] != metric or unlocked.has(entry["id"]):
				continue
			var goal: int = int(entry["target"])
			var ratio: float = float(mini(metric_value(stats, metric), goal)) / float(maxi(goal, 1))
			candidates.append({"id": entry["id"], "ratio": ratio, "order": i})
			break
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["ratio"]), float(b["ratio"])):
			return float(a["ratio"]) > float(b["ratio"])
		return int(a["order"]) < int(b["order"]))
	var out: Array[StringName] = []
	for candidate in candidates:
		if out.size() >= limit:
			break
		out.append(candidate["id"])
	return out


# --- Unvanlar --------------------------------------------------------------------

static func title_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in TITLES:
		out.append(entry["id"])
	return out


static func find_title(id: StringName) -> Dictionary:
	for entry in TITLES:
		if entry["id"] == id:
			return entry
	return {}


static func is_title(id: StringName) -> bool:
	return not find_title(id).is_empty()


## Görünen ad; bilinmeyen id varsayılanın adı (asla boş değil).
static func title_name(id: StringName) -> String:
	var entry: Dictionary = find_title(id)
	return String(entry["name"]) if not entry.is_empty() else String(TITLES[0]["name"])


## Unvanı açan başarım (varsayılan / bilinmeyen: boş).
static func title_source(id: StringName) -> StringName:
	var entry: Dictionary = find_title(id)
	return entry["achievement"] if not entry.is_empty() else &""


## Başarımın ödül unvanı (yoksa boş).
static func title_for_achievement(achievement_id: StringName) -> StringName:
	for entry in TITLES:
		if entry["achievement"] == achievement_id and achievement_id != &"":
			return entry["id"]
	return &""


## Varsayılan her zaman açık; diğerleri yalnız kaynak başarımı açıksa.
static func is_title_unlocked(id: StringName, unlocked: Array) -> bool:
	var entry: Dictionary = find_title(id)
	if entry.is_empty():
		return false
	var source: StringName = entry["achievement"]
	return source == &"" or unlocked.has(source)


static func unlocked_title_ids(unlocked: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in TITLES:
		if is_title_unlocked(entry["id"], unlocked):
			out.append(entry["id"])
	return out


## Kayıttaki ham seçim → geçerli unvan: bilinen + açık değilse varsayılan
## (bozuk / kilitli / bilinmeyen seçim ASLA gösterilmez ve kayda geri yazılmaz).
static func resolve_title(raw: Variant, unlocked: Array) -> StringName:
	if typeof(raw) != TYPE_STRING and typeof(raw) != TYPE_STRING_NAME:
		return DEFAULT_TITLE
	var id := StringName(String(raw))
	return id if is_title_unlocked(id, unlocked) else DEFAULT_TITLE
