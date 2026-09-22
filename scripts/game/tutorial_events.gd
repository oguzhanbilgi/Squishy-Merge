class_name TutorialEvents
extends RefCounted
## İlk açılış tutorial'ının analitik OLAY dikişi (M8.10). `AdEvents` ile aynı
## şekil, AYRI liste: reklam olay sözleşmesi (ADS_SYSTEM §7) M8.9'da
## donduruldu, onboarding olayları onu genişletmesin.
##
## SAĞLAYICI YOK — Firebase/analytics SDK bilerek entegre edilmedi (§24).
## Sağlayıcı gelince `subscribe()` ile bağlanır; tutorial koduna dokunulmaz.
##
## Olaylar:
##   tutorial_started   {source}
##   tutorial_step      {step, elapsed_ms, source}
##   tutorial_first_drop {elapsed_ms}
##   tutorial_first_merge {tier, elapsed_ms}
##   tutorial_completed {day_key, source, elapsed_ms}
##   tutorial_skipped   {day_key, source, step, elapsed_ms}
##
## KİŞİSEL/CİHAZ VERİSİ YOK: yalnız adım adı, süre ve kaynak. Kayda/diske
## hiçbir şey yazılmaz; son RECENT_LIMIT olay bellekte tutulur.

const RECENT_LIMIT: int = 100
const NAMES: Array[StringName] = [
	&"tutorial_started", &"tutorial_step", &"tutorial_first_drop",
	&"tutorial_first_merge", &"tutorial_completed", &"tutorial_skipped",
]

static var _listeners: Array[Callable] = []
static var _recent: Array[Dictionary] = []


static func emit(name: StringName, context: Dictionary = {}) -> void:
	assert(NAMES.has(name), "Tanımsız tutorial olayı: %s" % name)
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
