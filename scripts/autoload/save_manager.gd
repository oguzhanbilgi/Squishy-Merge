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
