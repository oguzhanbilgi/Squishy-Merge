extends Node
## Tüm SFX/müzik çalma noktası. M6'da gerçek ses dosyalarıyla doldurulacak.

const SFX_PLAYER_COUNT: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	for i in SFX_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_sfx_players.append(player)


func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_PLAYER_COUNT
	player.stream = stream
	player.pitch_scale = pitch
	player.play()
