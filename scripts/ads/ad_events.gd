class_name AdEvents
extends RefCounted
## Reklam analitik OLAY dikişi (M8.9-01). Yalnız olay adları ve bağlam;
## analitik SAĞLAYICI YOK — o sonraki milestone (Firebase vb. burada
## bilerek entegre edilmedi). Sağlayıcı gelince `subscribe()` ile bağlanır;
## MonetizationManager'a dokunulmaz.
##
## Olaylar (docs/monetization/ADS_SYSTEM.md §7):
##   rewarded_requested / rewarded_loaded / rewarded_load_failed /
##   rewarded_showed / rewarded_impression / rewarded_earned /
##   rewarded_dismissed / rewarded_show_failed
##   banner_loaded / banner_load_failed / banner_impression / banner_clicked
## Bağlam anahtarları: `placement` ("revive" / "refill" / "preload"),
## `power` (refill'de gücün kayıt anahtarı), `ad_id`, `code`, `message`,
## `stale` (geç/eşleşmeyen callback), `t_msec`.
##
## Son RECENT_LIMIT olay bellekte tutulur (testler ve cihaz teşhisi);
## kayda/diske hiçbir şey yazılmaz.

const RECENT_LIMIT: int = 200
const NAMES: Array[StringName] = [
	&"rewarded_requested", &"rewarded_loaded", &"rewarded_load_failed",
	&"rewarded_showed", &"rewarded_impression", &"rewarded_earned",
	&"rewarded_dismissed", &"rewarded_show_failed",
	&"banner_loaded", &"banner_load_failed", &"banner_impression", &"banner_clicked",
]

static var _listeners: Array[Callable] = []
static var _recent: Array[Dictionary] = []


static func emit(name: StringName, context: Dictionary = {}) -> void:
	assert(NAMES.has(name), "Tanımsız reklam olayı: %s" % name)
	var event: Dictionary = context.duplicate()
	event["name"] = name
	event["t_msec"] = Time.get_ticks_msec()
	_recent.append(event)
	while _recent.size() > RECENT_LIMIT:
		_recent.pop_front()
	for listener in _listeners:
		if listener.is_valid():
			listener.call(name, event)


## `callable(name: StringName, event: Dictionary)`.
static func subscribe(listener: Callable) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


static func unsubscribe(listener: Callable) -> void:
	_listeners.erase(listener)


static func recent() -> Array[Dictionary]:
	return _recent.duplicate()


static func clear_recent() -> void:
	_recent.clear()


static func count(name: StringName) -> int:
	var n: int = 0
	for event in _recent:
		if event["name"] == name:
			n += 1
	return n


static func last(name: StringName) -> Dictionary:
	for i in range(_recent.size() - 1, -1, -1):
		if _recent[i]["name"] == name:
			return _recent[i]
	return {}
