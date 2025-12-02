extends Timer

@export var audio_stream_player_2d: AudioStreamPlayer2D

func _ready() -> void:
	if not is_connected("timeout", Callable(self, "_on_timeout")):
		connect("timeout", Callable(self, "_on_timeout"))

func _on_timeout() -> void:
	audio_stream_player_2d.play()
