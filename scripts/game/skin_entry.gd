class_name SkinEntry
extends RefCounted
## Bir skin'in OYUNCUYA GÖRE durumu: katalog verisi (SkinData) + sahiplik /
## takılılık (SaveManager) + fiyat (Shop) tek nesnede.
##
## Koleksiyon, mağaza ve ana sayfa skin durumunu buradan okuyor; üçü de aynı
## kuralları ayrı ayrı türetmiyor ("sahip değil ama takılı" gibi çelişkiler
## yapısal olarak imkânsız: takılı yalnızca sahip olunan için true olabilir,
## SaveManager.equipped_skin_id() zaten doğruluyor).
##
## Salt okunur anlık görüntü: durum değişince (satın alma, equip) yeniden
## üretilir; SaveManager sinyalleri (`skin_granted` / `skin_equipped`)
## ekranlara "yeniden üret" demek için var.
##
## "Varsayılan" görünüm de bir SkinEntry: `skin == null`, `id == ""`, her
## zaman sahip olunan ve fiyatsız. Koleksiyon grid'inin ilk kartı bu.

const DEFAULT_ID: StringName = &""
const DEFAULT_NAME: String = "Varsayılan"
## Varsayılan kartın rarity satırı ("Common" yerine).
const DEFAULT_RARITY_LABEL: String = "Orijinal"
## Kilitli kartın adı yerine gösterilen metin: koleksiyon isimleri
## GİZLEMİYOR (mağaza zaten gösteriyor) — bu sabit yalnızca ad boşsa.
const UNKNOWN_NAME: String = "???"

## Önizlemenin türetildiği orijinal dumpling. Orta tier: küçükler kartta
## kayboluyor, büyükler kırpılıyor.
const PREVIEW_BASE_TEXTURE: Texture2D = preload("res://assets/visual/dumpling_tier3.png")

var id: StringName = DEFAULT_ID
var display_name: String = DEFAULT_NAME
var rarity: SkinData.Rarity = SkinData.Rarity.COMMON
## Hamur fiyatı; varsayılan görünüm için 0.
var price: int = 0
var owned: bool = true
var equipped: bool = false
## Katalog kaydı; varsayılan görünümde null.
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


## Placeholder tint'i (SkinVisual'a gidiyor); varsayılanda beyaz.
func tint() -> Color:
	return skin.tint if skin != null else Color.WHITE


## Hazır önizleme görseli varsa o, yoksa null (çağıran orijinal dumpling +
## SkinVisual ile türetir — bkz. SkinSwatch).
func preview_texture() -> Texture2D:
	if skin != null and skin.preview_texture != null:
		return skin.preview_texture
	return null


# --- Üretim ---

static func default_entry() -> SkinEntry:
	var entry := SkinEntry.new()
	entry.equipped = SaveManager.equipped_skin_id() == DEFAULT_ID
	return entry


static func for_skin(skin_data: SkinData) -> SkinEntry:
	var entry := SkinEntry.new()
	entry.skin = skin_data
	entry.id = skin_data.id
	entry.display_name = skin_data.display_name if not skin_data.display_name.is_empty() else UNKNOWN_NAME
	entry.rarity = skin_data.rarity
	entry.price = Shop.price_of(skin_data)
	entry.owned = SaveManager.owns_skin(skin_data.id)
	entry.equipped = entry.owned and SaveManager.equipped_skin_id() == skin_data.id
	return entry


## id'ye göre tek giriş; DEFAULT_ID varsayılanı, bilinmeyen id null döner.
static func find(skin_id: StringName) -> SkinEntry:
	if skin_id == DEFAULT_ID:
		return default_entry()
	var skin_data: SkinData = SkinLibrary.find(skin_id)
	return for_skin(skin_data) if skin_data != null else null


## Katalog sırasında (rarity, id) bütün girişler; `with_default` true ise
## başa "Varsayılan" eklenir (koleksiyon), false ise yalnız skinler (mağaza).
static func all(with_default: bool) -> Array[SkinEntry]:
	var result: Array[SkinEntry] = []
	if with_default:
		result.append(default_entry())
	for skin_data in SkinLibrary.all():
		result.append(for_skin(skin_data))
	return result


## Takılı girişin kendisi (varsayılan dahil, hiç null dönmez).
static func equipped_entry() -> SkinEntry:
	return find(SaveManager.equipped_skin_id())


## Sahip olunan KATALOGDAKİ skin sayısı. Kayıttaki liste artık var olmayan
## bir id içerse de burası saymaz — dört ekranın "18/20"si aynı sayı olsun.
static func owned_count() -> int:
	var count: int = 0
	for skin_data in SkinLibrary.all():
		if SaveManager.owns_skin(skin_data.id):
			count += 1
	return count
