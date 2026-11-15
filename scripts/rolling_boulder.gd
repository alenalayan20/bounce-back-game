extends Area2D
## The painted level's chase route, followed by the existing eight-frame boulder.
## Route points and the release rectangle are in the parent level's coordinates.

signal started
signal route_finished

@export var speed: float = 200.0
@export var trigger_rect: Rect2 = Rect2(360.0, -120.0, 920.0, 360.0)
@export var trajectory: PackedVector2Array = PackedVector2Array([
	Vector2(152, 154), Vector2(205, 180), Vector2(1136, 180),
	Vector2(1158, 182), Vector2(1177, 194), Vector2(1190, 216),
	Vector2(1194, 244), Vector2(1177, 254), Vector2(1044, 334),
	Vector2(166, 334), Vector2(143, 338), Vector2(123, 353),
	Vector2(108, 380), Vector2(101, 415), Vector2(103, 457),
	Vector2(255, 570), Vector2(1090, 570),
])

var active: bool = true
var released: bool = false
var route_complete: bool = false
var distance_travelled: float = 0.0
var _next_point: int = 1

@onready var visual: AnimatedSprite2D = $Visual
@onready var boulder_collider: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	reset()


func _physics_process(delta: float) -> void:
	if not active:
		return
	if released and not route_complete:
		_advance_route(maxf(0.0, speed) * delta)
	for node in get_tree().get_nodes_in_group(&"player"):
		if not node is Node2D or not _is_live_player(node):
			continue
		var player: Node2D = node
		if not released and trigger_rect.has_point(get_parent().to_local(player.global_position)):
			activate()
		# Check live shapes as well as Area2D events: the level can teleport both
		# objects on restart before an old body_entered notification is delivered.
		if active and _currently_overlaps(player):
			player.call(&"die")


func activate() -> void:
	if not active or released or trajectory.size() < 2:
		return
	released = true
	_update_animation_direction(trajectory[_next_point] - position)
	started.emit()


func reset() -> void:
	if not trajectory.is_empty():
		position = trajectory[0]
	_next_point = 1
	released = false
	route_complete = false
	distance_travelled = 0.0
	visual.stop()
	visual.animation = &"default"
	visual.frame = 0
	visual.frame_progress = 0.0
	visual.speed_scale = 1.0
	visual.rotation = 0.0
	visual.flip_h = false
	set_active(true)


func set_active(value: bool) -> void:
	active = value
	set_deferred(&"monitoring", value)
	if active and released and not route_complete and _next_point < trajectory.size():
		_update_animation_direction(trajectory[_next_point] - position)
	else:
		visual.pause()


func _advance_route(remaining: float) -> void:
	while remaining > 0.0 and _next_point < trajectory.size():
		var offset: Vector2 = trajectory[_next_point] - position
		var segment_left: float = offset.length()
		if segment_left <= 0.001:
			position = trajectory[_next_point]
			_next_point += 1
			continue
		_update_animation_direction(offset)
		var step: float = minf(remaining, segment_left)
		position += offset * (step / segment_left)
		distance_travelled += step
		remaining -= step
		if step >= segment_left:
			position = trajectory[_next_point]
			_next_point += 1
	if _next_point >= trajectory.size() and not route_complete:
		route_complete = true
		visual.pause()
		route_finished.emit()


func _update_animation_direction(direction: Vector2) -> void:
	# The supplied frames already roll. Reversing the frame sequence on the
	# middle lane avoids adding a second rotation to the artist's animation.
	var playback_direction: float = -1.0 if direction.x < 0.0 else 1.0
	visual.play(&"default", playback_direction)


func _is_live_player(body: Node2D) -> bool:
	return body.is_in_group(&"player") and body.has_method(&"die") \
		and not body.get(&"dead") and not body.get(&"finished")


func _on_body_entered(body: Node2D) -> void:
	if active and _is_live_player(body) and _currently_overlaps(body):
		body.call(&"die")


func _currently_overlaps(body: Node2D) -> bool:
	if not body is CollisionObject2D or boulder_collider.disabled or boulder_collider.shape == null:
		return false
	for owner_id in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var body_transform: Transform2D = body.global_transform * body.shape_owner_get_transform(owner_id)
		for shape_index in range(body.shape_owner_get_shape_count(owner_id)):
			var body_shape: Shape2D = body.shape_owner_get_shape(owner_id, shape_index)
			if body_shape != null and boulder_collider.shape.collide(boulder_collider.global_transform, body_shape, body_transform):
				return true
	return false
