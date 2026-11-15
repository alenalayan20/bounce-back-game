extends AudioStreamPlayer
## Short concrete steps follow distance travelled instead of looping a recording.

const VARIANTS := [
	preload("res://audio/sfx/footstep_01.wav"),
	preload("res://audio/sfx/footstep_02.wav"),
	preload("res://audio/sfx/footstep_03.wav"),
]

@export var step_distance: float = 84.0
var played_steps: int = 0
var _travelled: float = 0.0
var _walking: bool = false

func update_steps(distance: float, walking: bool) -> void:
	if not walking:
		reset_steps()
		return
	if not _walking:
		_walking = true
		_play_step()
	_travelled += distance
	if _travelled >= step_distance:
		_travelled = fposmod(_travelled, step_distance)
		_play_step()

func reset_steps() -> void:
	_travelled = 0.0
	_walking = false
	stop()

func _play_step() -> void:
	stream = VARIANTS[played_steps % VARIANTS.size()]
	pitch_scale = [0.98, 1.015, 1.0][played_steps % 3]
	played_steps += 1
	play()
