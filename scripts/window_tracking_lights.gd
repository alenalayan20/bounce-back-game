extends Node2D
## The windows stay in place while their soft blue beams follow the character.

@export var window_origins: PackedVector2Array = PackedVector2Array([Vector2(244, 267), Vector2(633, 267), Vector2(973, 267)])
@export_range(0.5, 15.0, 0.1) var tracking_speed: float = 2.2
@export_range(0.0, 0.5, 0.005) var intensity: float = 0.085
@export var target_offset: Vector2 = Vector2(0, -32)
@export_range(30.0, 200.0, 1.0) var beam_end_width: float = 160.0
@export_range(150.0, 700.0, 10.0) var max_beam_length: float = 340.0
@export_range(0.0, 0.5, 0.01) var character_light_energy: float = 0.0

var tracked_target: Vector2 = Vector2.ZERO
var beam_targets: PackedVector2Array = PackedVector2Array()

var _target: Node2D
var _has_target: bool = false
var _beams: Array[Polygon2D] = []
var _beam_material: ShaderMaterial
var _character_light: PointLight2D


func _ready() -> void:
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = preload("res://shaders/tracking_beam.gdshader")
	_beam_material.set_shader_parameter("intensity", intensity)
	# Polygon2D only supplies custom UV coordinates when a texture exists.
	var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_image.fill(Color.WHITE)
	var white_texture := ImageTexture.create_from_image(white_image)
	for i in range(window_origins.size()):
		var beam := Polygon2D.new()
		beam.name = "WindowBeam%d" % (i + 1)
		beam.material = _beam_material
		beam.texture = white_texture
		beam.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		add_child(beam)
		_beams.append(beam)
	_make_character_light()
	# The player can become ready later in the same parent scene.
	_try_find_target()
	_update_beams()


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_try_find_target()
	if not is_instance_valid(_target):
		return
	var desired := to_local(_target.global_position + target_offset)
	if not _has_target:
		tracked_target = desired
		_has_target = true
	else:
		tracked_target = tracked_target.lerp(desired, 1.0 - exp(-tracking_speed * delta))
	_beam_material.set_shader_parameter("intensity", intensity)
	_update_beams()
	# Radial highlighting is disabled by default: only the soft window rays
	# should follow the player, without a bright patch around the character.
	_character_light.position = tracked_target
	_character_light.energy = character_light_energy
	_character_light.enabled = character_light_energy > 0.0


func snap_to_player() -> void:
	_try_find_target()
	if is_instance_valid(_target):
		tracked_target = to_local(_target.global_position + target_offset)
		_has_target = true
		_update_beams()


func _try_find_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(_target) and not _has_target:
		tracked_target = to_local(_target.global_position + target_offset)
		_has_target = true


func _update_beams() -> void:
	beam_targets.clear()
	for i in range(_beams.size()):
		var origin := window_origins[i]
		var difference := tracked_target - origin
		var length := difference.length()
		var direction := difference / length if length > 1.0 else Vector2.DOWN
		var normal := Vector2(-direction.y, direction.x)
		var end := origin + direction * clampf(length + 24.0, 96.0, max_beam_length)
		var start := origin + direction * 4.0
		var start_half_width: float = 23.0
		var end_half_width: float = beam_end_width * 0.5
		_beams[i].polygon = PackedVector2Array([
			start - normal * start_half_width,
			start + normal * start_half_width,
			end + normal * end_half_width,
			end - normal * end_half_width,
		])
		_beams[i].visible = _has_target
		beam_targets.append(end)


func _make_character_light() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(0.4, 0.4, 0.4, 1), Color.BLACK])
	var texture := GradientTexture2D.new()
	texture.width = 192
	texture.height = 192
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	_character_light = PointLight2D.new()
	_character_light.name = "CharacterLight"
	_character_light.texture = texture
	_character_light.color = Color(0.35, 0.7, 1.0)
	_character_light.energy = character_light_energy
	_character_light.enabled = character_light_energy > 0.0
	_character_light.shadow_enabled = false
	add_child(_character_light)
