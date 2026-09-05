extends Node
## Yerel kalıcı kayıt (bulut yok). JSON olarak user:// altında tutulur.

const SAVE_PATH: String = "user://squishy_merge_save.json"

var data: Dictionary = {}

const DEFAULT_DATA: Dictionary = {
	"highest_level_unlocked": 1,
	"level_stars": {},
	"endless_high_score": 0,
	"dough": 0,
	"unlocked_skins": [],
	"total_merges": 0,
	"merges_since_bonus_chest": 0,
	"daily_streak": 0,
	"last_login_date": "",
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Kayıt dosyası açılamadı: %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Kayıt dosyası bozuk, varsayılanlara dönülüyor.")
		return
	for key: String in parsed:
		data[key] = parsed[key]


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt dosyası yazılamadı: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# --- İlerleme (M2) ---

func highest_level_unlocked() -> int:
	return int(data.get("highest_level_unlocked", 1))


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= highest_level_unlocked()


## Level tamamlandığında bir sonrakini açar. Geriye gitmez.
func complete_level(level_number: int) -> void:
	if level_number + 1 > highest_level_unlocked():
		data["highest_level_unlocked"] = level_number + 1
		save_game()


## Sonsuz mod level 10 bitince açılır (GAME_DESIGN.md §4).
func is_endless_unlocked(total_levels: int) -> bool:
	return highest_level_unlocked() > total_levels


func endless_high_score() -> int:
	return int(data.get("endless_high_score", 0))


## Yeni rekor kırıldıysa true döner.
func record_endless_score(score: int) -> bool:
	if score <= endless_high_score():
		return false
	data["endless_high_score"] = score
	save_game()
	return true


# --- Koleksiyon, para ve sandık sayacı (M3) ---

func dough() -> int:
	return int(data.get("dough", 0))


func add_dough(amount: int) -> void:
	data["dough"] = dough() + amount
	save_game()


func owned_skins() -> Array:
	return data.get("unlocked_skins", [])


func owns_skin(id: StringName) -> bool:
	return owned_skins().has(String(id))


func grant_skin(id: StringName) -> void:
	if owns_skin(id):
		return
	var owned: Array = owned_skins().duplicate()
	owned.append(String(id))
	data["unlocked_skins"] = owned
	save_game()


## Round sonunda çağrılır. Toplam merge sayacını ilerletir ve hak edilen
## bonus sandık sayısını döner (GAME_DESIGN.md §5.2: her 75 merge'de bir).
func add_merges(count: int) -> int:
	if count <= 0:
		return 0
	data["total_merges"] = int(data.get("total_merges", 0)) + count
	var pending: int = int(data.get("merges_since_bonus_chest", 0)) + count
	var chests: int = pending / ChestSystem.MERGES_PER_BONUS_CHEST
	data["merges_since_bonus_chest"] = pending % ChestSystem.MERGES_PER_BONUS_CHEST
	save_game()
	return chests


func stars_for_level(level_number: int) -> int:
	return int(data.get("level_stars", {}).get(str(level_number), 0))


## Yıldız sadece yukarı gider — daha kötü bir tekrar oynayış eskisini silmez.
func record_stars(level_number: int, stars: int) -> void:
	if stars <= stars_for_level(level_number):
		return
	var all_stars: Dictionary = data.get("level_stars", {}).duplicate()
	all_stars[str(level_number)] = stars
	data["level_stars"] = all_stars
	save_game()
