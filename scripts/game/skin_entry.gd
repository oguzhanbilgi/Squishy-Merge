class_name SkinEntry
extends RefCounted
## Bir koleksiyon parçasının (Squishy) OYUNCUYA GÖRE durumu: katalog verisi
## (SkinData) + sahiplik / vitrin (SaveManager) + fiyat (Shop) tek nesnede.
##
## Ad TARİHSEL ("skin", M8.5): TASK/044'ten beri parçalar gameplay'i DEĞİŞTİRMEZ —
## oyuncuya "koleksiyon parçası / Squishy". Kimlikler / sınıf adları eski kayıtlar
## ve dosya yolları bozulmasın diye değişmedi.
##
## Koleksiyon, mağaza, ana sayfa ve profil durumu buradan okuyor; hiçbiri aynı
## kuralları ayrı ayrı türetmiyor ("sahip değil ama vitrinde" gibi çelişkiler
## yapısal olarak imkânsız: vitrin yalnız sahip olunan için true olabilir,
## SaveManager.profile_showcase() zaten doğruluyor).
##
## Salt okunur anlık görüntü: durum değişince (satın alma, vitrin) yeniden
## üretilir; SaveManager sinyalleri (`skin_granted` / `showcase_changed`)
## ekranlara "yeniden üret" demek için var.
##
## "Varsayılan" (kanonik Squishy) da bir SkinEntry: `skin == null`, `id == ""`,
## her zaman sahip olunan ve fiyatsız. Koleksiyon parçası DEĞİL (albümde yok,
## sayaca girmez); vitrin boşken profil avatarı bu.

const DEFAULT_ID: StringName = &""
const DEFAULT_NAME: String = "Varsayılan"
## Varsayılanın rarity satırı ("Common" yerine).
const DEFAULT_RARITY_LABEL: String = "Orijinal"
## Kilitli kartın adı yerine gösterilen metin: koleksiyon isimleri
## GİZLEMİYOR (mağaza zaten gösteriyor) — bu sabit yalnızca ad boşsa.
const UNKNOWN_NAME: String = "???"

## Varsayılan (kanonik) Squishy görseli — oyundaki tier 3 dumpling'in kendisi.
## Orta tier: küçükler kartta kayboluyor, büyükler kırpılıyor.
const PREVIEW_BASE_TEXTURE: Texture2D = preload("res://assets/visual/dumpling_tier3.png")

var id: StringName = DEFAULT_ID
var display_name: String = DEFAULT_NAME
var rarity: SkinData.Rarity = SkinData.Rarity.COMMON
## Hamur fiyatı; varsayılan görünüm için 0.
var price: int = 0
var owned: bool = true
## Profil vitrininde mi (TASK/044) ve hangi yuvada (0 = avatar, -1 = değil).
var showcased: bool = false
var showcase_slot: int = -1
## Katalog kaydı; varsayılanda null.
var skin: SkinData = null


func is_default() -> bool:
	return skin == null


func is_locked() -> bool:
	return not owned


## Satın alınabilir: kilitli ve fiyatı var (varsayılan asla satılmaz).
func is_purchasable() -> bool:
	return is_locked() and price > 0


func can_afford() -> bool:
	return is_purchasable() and SaveManager.dough() >= price


func rarity_label() -> String:
	if is_default():
		return DEFAULT_RARITY_LABEL
	return SkinData.rarity_name(rarity)


## Kart/hero vurgu rengi. Varsayılan için nötr beyaz.
func rarity_color() -> Color:
	if is_default():
		return Color(1, 1, 1, 0.55)
	return SkinData.rarity_color(rarity)


## Final önizleme görseli (M8.5-14'ten beri 20 parçanın hepsinde dolu);
## null ise çağıran kanonik Squishy'yi (PREVIEW_BASE_TEXTURE) çizer.
func preview_texture() -> Texture2D:
	if skin != null and skin.preview_texture != null:
		return skin.preview_texture
	return null


## Çizilecek görsel: parçanın final sanatı, yoksa kanonik Squishy.
func art_texture() -> Texture2D:
	var ready_made: Texture2D = preview_texture()
	return ready_made if ready_made != null else PREVIEW_BASE_TEXTURE


# --- Üretim ---

static func default_entry() -> SkinEntry:
	return SkinEntry.new()


static func for_skin(skin_data: SkinData) -> SkinEntry:
	var entry := SkinEntry.new()
	entry.skin = skin_data
	entry.id = skin_data.id
	entry.display_name = skin_data.display_name if not skin_data.display_name.is_empty() else UNKNOWN_NAME
	entry.rarity = skin_data.rarity
	entry.price = Shop.price_of(skin_data)
	entry.owned = SaveManager.owns_skin(skin_data.id)
	entry.showcase_slot = SaveManager.showcase_slot(skin_data.id) if entry.owned else -1
	entry.showcased = entry.showcase_slot >= 0
	return entry


## id'ye göre tek giriş; DEFAULT_ID varsayılanı, bilinmeyen id null döner.
static func find(skin_id: StringName) -> SkinEntry:
	if skin_id == DEFAULT_ID:
		return default_entry()
	var skin_data: SkinData = SkinLibrary.find(skin_id)
	return for_skin(skin_data) if skin_data != null else null


## Katalog sırasında (rarity, id) bütün girişler; `with_default` true ise
## başa "Varsayılan" eklenir, false ise yalnız 20 koleksiyon parçası (albüm,
## mağaza).
static func all(with_default: bool) -> Array[SkinEntry]:
	var result: Array[SkinEntry] = []
	if with_default:
		result.append(default_entry())
	for skin_data in SkinLibrary.all():
		result.append(for_skin(skin_data))
	return result


## Vitrindeki girişler, yuva sırasıyla (en fazla 3; boş vitrin = boş dizi).
static func showcase_entries() -> Array[SkinEntry]:
	var result: Array[SkinEntry] = []
	for showcase_id in SaveManager.profile_showcase():
		var entry: SkinEntry = find(showcase_id)
		if entry != null:
			result.append(entry)
	return result


## Profil avatarı (TASK/044): vitrinin İLK parçası; vitrin boşsa kanonik Squishy
## (varsayılan). Hiç null dönmez.
static func avatar_entry() -> SkinEntry:
	var showcase: Array[StringName] = SaveManager.profile_showcase()
	if not showcase.is_empty():
		var entry: SkinEntry = find(showcase[0])
		if entry != null:
			return entry
	return default_entry()


## En son keşfedilen (kazanılma sırasında sonuncu) katalog parçası; hiç yoksa null.
## Ana Sayfa Koleksiyon madalyonu bunu gösterir (takma / seçim anlamı YOK).
static func newest_owned() -> SkinEntry:
	var owned_ids: Array = SaveManager.owned_skins()
	for i in range(owned_ids.size() - 1, -1, -1):
		var raw: Variant = owned_ids[i]
		if typeof(raw) != TYPE_STRING:
			continue
		var entry: SkinEntry = find(StringName(String(raw)))
		if entry != null and not entry.is_default():
			return entry
	return null


## Sahip olunan KATALOGDAKİ parça sayısı. Kayıttaki liste artık var olmayan
## bir id içerse de burası saymaz — bütün ekranların "7/20"si aynı sayı olsun.
static func owned_count() -> int:
	var count: int = 0
	for skin_data in SkinLibrary.all():
		if SaveManager.owns_skin(skin_data.id):
			count += 1
	return count


## Rarity başına sahip olunan / toplam (albüm başlığı ve profil).
static func owned_count_by_rarity(rarity_value: SkinData.Rarity) -> int:
	var count: int = 0
	for skin_data in SkinLibrary.by_rarity(rarity_value):
		if SaveManager.owns_skin(skin_data.id):
			count += 1
	return count
