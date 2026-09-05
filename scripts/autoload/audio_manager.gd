extends Node
## Tüm SFX çalma noktası. Bus yapısı: Master -> SFX / Music
## (default_bus_layout.tres).
##
## Ses dosyaları Kenney.nl CC0 PLACEHOLDER — owner kendi asset'leriyle
## değiştirecek. Değişimin kod dokunmadan olması için dosya isimleri sabit
## tutulmalı; çağrı noktaları aşağıdaki kimliklere bağlı, dosya yollarına değil.

const SFX_PLAYER_COUNT: int = 8
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"

const SFX_PATHS: Dictionary = {
	&"merge": "res://assets/audio/sfx_merge_pop.ogg",
	&"danger": "res://assets/audio/sfx_danger.ogg",
	&"star_pat": "res://assets/audio/sfx_star_pat.ogg",
	&"chest_open": "res://assets/audio/sfx_chest_open.ogg",
	&"combo": "res://assets/audio/sfx_combo.ogg",
	&"level_win": "res://assets/audio/sfx_level_win.ogg",
	&"level_lose": "res://assets/audio/sfx_level_lose.ogg",
}

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	_load_streams()
	var bus: StringName = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"
	if bus != SFX_BUS:
		push_warning("SFX bus'ı bulunamadı, Master'a düşülüyor.")
	for i in SFX_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_sfx_players.append(player)


func _load_streams() -> void:
	for id: StringName in SFX_PATHS:
		var path: String = SFX_PATHS[id]
		if not ResourceLoader.exists(path):
			push_warning("Ses dosyası yok: %s (id: %s)" % [path, id])
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("Ses dosyası yüklenemedi: %s" % path)
			continue
		# Tek atışlık efektler; loop açık kalırsa ses hiç bitmez.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		_streams[id] = stream


## Aynı sample farklı pitch'lerde çalınıyor — tier başına escalation
## (GAME_DESIGN.md §6) ayrı dosya gerektirmiyor.
func play_sfx(id: StringName, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_PLAYER_COUNT
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func set_bus_volume_db(bus: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, volume_db)
