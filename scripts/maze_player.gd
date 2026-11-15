extends CharacterBody2D
## The existing front-facing 1d animation is used as the maze's top-down hero.

signal died

@export var speed: float = 230.0

var face_direction: Vector2 = Vector2.DOWN
var dead: bool = false
var finished: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk_sound: AudioStreamPlayer = $WalkSound


func _ready() -> void:
	add_to_group("player")
	add_to_group("maze_player")
	_set_idle()


func _physics_process(delta: float) -> void:
	if dead or finished:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# CharacterBody2D moves in global pixels. Keep Speed in the map's units
	# when the full 1672×941 maze is scaled into the game's 1280×720 view.
	velocity = direction * speed * global_scale
	if not direction.is_zero_approx():
		face_direction = direction.normalized()
		sprite.rotation = face_direction.angle() - PI * 0.5
	move_and_slide()
	var walking := get_real_velocity().length() > 8.0
	if walking:
		if not sprite.is_playing() or sprite.animation != &"1d_run":
			sprite.play(&"1d_run")
	else:
		_set_idle()
	walk_sound.call("update_steps", get_real_velocity().length() * delta / maxf(global_scale.x, 0.001), walking)


func _set_idle() -> void:
	sprite.stop()
	sprite.animation = &"1d_run"
	sprite.frame = 0


func respawn(at: Vector2) -> void:
	walk_sound.call("reset_steps")
	global_position = at
	velocity = Vector2.ZERO
	dead = false
	finished = false
	face_direction = Vector2.DOWN
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	_set_idle()
	move_and_slide()


func finish() -> void:
	if dead or finished:
		return
	finished = true
	velocity = Vector2.ZERO
	walk_sound.call("reset_steps")
	_set_idle()


func die() -> void:
	if dead or finished:
		return
	dead = true
	velocity = Vector2.ZERO
	walk_sound.call("reset_steps")
	_set_idle()
	died.emit()


func _exit_tree() -> void:
	if is_instance_valid(walk_sound):
		walk_sound.stop()
