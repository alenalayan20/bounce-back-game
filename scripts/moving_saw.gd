extends Area2D
## A moving blade with replaceable existing scene, SpriteFrames and sound.

@export var min_x: float = 800.0
@export var max_x: float = 1020.0
@export var start_x: float = 858.0
@export var speed: float = 90.0
@export var rotation_speed: float = 10.0
@export var visual_scene: PackedScene
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"default"
@export var visual_scale: Vector2 = Vector2.ONE
@export var sound_stream: AudioStream
@export var sound_volume_db: float = -10.0

@onready var visual: Node2D = $Visual
@onready var sound: AudioStreamPlayer = $Sound
@onready var blade_collider: CollisionShape2D = $CollisionShape2D

var direction: float = 1.0
var active: bool = true
var _phase: float = 0.0
var _uses_fallback: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_install_visual()
	_install_audio()
	reset()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var span: float = maxf(0.0, max_x - min_x)
	if span > 0.0:
		_phase = fposmod(_phase + absf(speed) * delta, span * 2.0)
		if _phase < span:
			position.x = min_x + _phase
			direction = 1.0
		else:
			position.x = max_x - (_phase - span)
			direction = -1.0
	if _uses_fallback:
		visual.rotation = fposmod(visual.rotation + rotation_speed * delta, TAU)


func _install_visual() -> void:
	if visual_scene == null and sprite_frames == null:
		return
	_uses_fallback = false
	$Visual/Fallback.hide()
	var imported: Node
	if visual_scene != null:
		imported = visual_scene.instantiate()
	else:
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = sprite_frames
		imported = animated
	visual.add_child(imported)
	if imported is Node2D:
		imported.scale = visual_scale
	_start_existing_animation(imported)


func _start_existing_animation(node: Node) -> void:
	if node is AnimatedSprite2D:
		if node.sprite_frames != null and node.sprite_frames.has_animation(animation_name):
			node.play(animation_name)
		else:
			node.play()
	elif node is AnimationPlayer and node.has_animation(animation_name):
		node.play(animation_name)
	for child in node.get_children():
		_start_existing_animation(child)


func _install_audio() -> void:
	if sound_stream == null:
		return
	var looping: AudioStream = sound_stream.duplicate()
	if looping is AudioStreamMP3 or looping is AudioStreamOggVorbis:
		looping.loop = true
	elif looping is AudioStreamWAV:
		looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if looping.loop_end <= looping.loop_begin:
			looping.loop_end = int(looping.get_length() * looping.mix_rate)
	sound.stream = looping
	sound.volume_db = sound_volume_db
	# A finished signal is a fallback for other imported AudioStream types.
	sound.finished.connect(_on_sound_finished)


func _on_sound_finished() -> void:
	if active and sound.stream != null:
		sound.play()


func reset() -> void:
	var span: float = maxf(0.0, max_x - min_x)
	_phase = clampf(start_x - min_x, 0.0, span)
	position.x = min_x + _phase
	direction = 1.0
	visual.rotation = 0.0
	set_active(true)
	if sound.stream != null:
		sound.play()


func set_active(value: bool) -> void:
	active = value
	visual.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	set_deferred("monitoring", value)
	if value:
		if sound.stream != null and not sound.playing:
			sound.play()
	else:
		sound.stop()


func _on_body_entered(body: Node2D) -> void:
	# Monitoring changes are deferred. An enter queued before a respawn can
	# arrive after both objects have been teleported, so verify live geometry.
	if active and body.has_method("die") and _currently_overlaps(body):
		body.die()


func _currently_overlaps(body: Node2D) -> bool:
	if not body is CollisionObject2D or blade_collider.disabled or blade_collider.shape == null:
		return false
	for owner_id in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var body_shape_transform: Transform2D = body.global_transform * body.shape_owner_get_transform(owner_id)
		for shape_index in range(body.shape_owner_get_shape_count(owner_id)):
			var body_shape: Shape2D = body.shape_owner_get_shape(owner_id, shape_index)
			if body_shape != null and blade_collider.shape.collide(blade_collider.global_transform, body_shape, body_shape_transform):
				return true
	return false
