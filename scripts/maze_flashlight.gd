extends Node2D
## The maze is black except for a soft, wall-occluded torch carried by the player.

@export_range(160.0, 360.0, 10.0) var flashlight_range: float = 260.0
@export_range(35.0, 85.0, 1.0) var cone_angle_degrees: float = 58.0
@export_range(30.0, 70.0, 1.0) var body_halo_radius: float = 52.0
@export_range(0.6, 1.8, 0.05) var brightness: float = 1.25
@export_range(2.0, 14.0, 0.5) var aim_speed: float = 8.0

@onready var light: PointLight2D = $Light
@onready var darkness: CanvasModulate = $Darkness

var facing: Vector2 = Vector2.DOWN
var _target: Node2D


func _ready() -> void:
	darkness.color = Color.BLACK
	light.texture = _make_torch_texture()
	light.texture_scale = flashlight_range * 2.0 / 512.0
	light.energy = brightness
	_find_target()
	_snap_to_target()
	queue_redraw()


func _draw() -> void:
	# A small carried torch sits in front of the hero's hands. Its light is
	# still supplied by the shadow-casting PointLight2D, rather than this art.
	draw_rect(Rect2(-3.5, 15, 7, 14), Color(0.22, 0.25, 0.29), true)
	draw_rect(Rect2(-4.5, 26, 9, 5), Color(0.42, 0.43, 0.42), true)
	draw_circle(Vector2(0, 31), 3.0, Color(1.0, 0.88, 0.54))


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
	if is_instance_valid(_target):
		global_position = _target.global_position
		var direction = _target.get("face_direction")
		if direction is Vector2:
			aim(direction)
	var desired_rotation: float = facing.angle() - PI * 0.5
	rotation = lerp_angle(rotation, desired_rotation, 1.0 - exp(-aim_speed * delta))
	light.energy = brightness


func set_target(player: Node2D) -> void:
	_target = player
	_snap_to_target()


func aim(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		facing = direction.normalized()


func _find_target() -> void:
	_target = get_tree().get_first_node_in_group("maze_player") as Node2D


func _snap_to_target() -> void:
	if not is_instance_valid(_target):
		return
	global_position = _target.global_position
	var direction = _target.get("face_direction")
	if direction is Vector2:
		aim(direction)
	rotation = facing.angle() - PI * 0.5


func _make_torch_texture() -> ImageTexture:
	# This is a light cookie, generated once. Its black pixels emit no light.
	# Keeping the world at CanvasModulate.BLACK also hides painted-in lamps.
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var inner_cosine: float = cos(deg_to_rad(cone_angle_degrees * 0.34))
	var outer_cosine: float = cos(deg_to_rad(cone_angle_degrees * 0.65))
	var halo_ratio: float = body_halo_radius / flashlight_range
	for y in range(512):
		for x in range(512):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(256, 256)) / 256.0
			var distance: float = p.length()
			var forward_dot: float = p.y / maxf(distance, 0.0001)
			var angular: float = smoothstep(outer_cosine, inner_cosine, forward_dot)
			var falloff: float = 1.0 - smoothstep(0.12, 1.0, distance)
			var beam: float = angular * falloff
			var halo: float = 0.75 * (1.0 - smoothstep(halo_ratio * 0.15, halo_ratio, distance))
			var value: float = clampf(maxf(beam, halo), 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)
