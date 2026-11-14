extends CharacterBody2D
## Side-view player. The node's origin is at the feet, not the sprite's centre.

signal died

@export var speed: float = 280.0
@export var jump_velocity: float = -540.0
@export var gravity: float = 1600.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.08
@export var jump_buffer_time: float = 0.10

var dead: bool = false
var finished: bool = false
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _death_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var walk_sound: AudioStreamPlayer = $WalkSound
@onready var jump_sound: AudioStreamPlayer = $JumpSound


func _ready() -> void:
	add_to_group("player")
	sprite.play(&"idle")
	var walking_stream := walk_sound.stream as AudioStreamMP3
	if walking_stream != null:
		walking_stream.loop = true


func _physics_process(delta: float) -> void:
	if dead or finished:
		return

	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_left = jump_buffer_time

	var direction := Input.get_axis(&"move_left", &"move_right")
	velocity.x = direction * speed
	if not is_zero_approx(direction):
		sprite.flip_h = direction < 0.0

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		jump_sound.play()
	elif not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	# A quick tap gives a short jump; holding the key gives the full arc.
	if Input.is_action_just_released(&"jump") and velocity.y < jump_velocity * 0.45:
		velocity.y = jump_velocity * 0.45

	move_and_slide()
	_update_animation()
	_update_walk_sound()
	if global_position.y > 800.0:
		die()


func _update_animation() -> void:
	var animation_name: StringName
	if not is_on_floor():
		animation_name = &"jump" if velocity.y < -30.0 else &"fall"
	elif absf(velocity.x) > 1.0:
		animation_name = &"run"
	else:
		animation_name = &"idle"
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _update_walk_sound() -> void:
	# Actual velocity avoids playing footsteps while pushing into a wall.
	var walking := not dead and not finished and is_on_floor() and absf(get_real_velocity().x) > 10.0
	if walking:
		if not walk_sound.playing:
			walk_sound.play()
	elif walk_sound.playing:
		walk_sound.stop()


func die() -> void:
	if dead or finished:
		return
	dead = true
	walk_sound.stop()
	jump_sound.stop()
	death_sound.play()
	velocity = Vector2.ZERO
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	sprite.stop()
	sprite.modulate = Color(1.0, 0.25, 0.2)
	_death_tween = create_tween()
	_death_tween.tween_property(sprite, "modulate:a", 0.2, 0.45)
	died.emit()


func respawn(at: Vector2) -> void:
	walk_sound.stop()
	jump_sound.stop()
	# Let the short death clip finish naturally across the quick respawn.
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	global_position = at
	velocity = Vector2.ZERO
	dead = false
	finished = false
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	sprite.modulate = Color.WHITE
	sprite.flip_h = false
	sprite.play(&"idle")
	# Clear the old floor contact before accepting another jump after teleporting.
	move_and_slide()


func finish() -> void:
	if dead or finished:
		return
	finished = true
	walk_sound.stop()
	jump_sound.stop()
	velocity = Vector2.ZERO
	_jump_buffer_left = 0.0
	sprite.play(&"idle")
