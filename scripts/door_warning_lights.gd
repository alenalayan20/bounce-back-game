extends Node2D
## Slow red warning lamps. Only the small emissive art is visible in darkness;
## this glow does not add a world light or reveal the maze's painted corridors.

@export var lamp_positions: PackedVector2Array = PackedVector2Array([Vector2(1186, 472)])
@export var background_path: NodePath = NodePath("../Background")
## Centers in the original artwork, before any background UV door scaling.
@export var baked_lamp_centers: PackedVector2Array = PackedVector2Array([Vector2(1186, 487)])
@export var lamp_half_size: Vector2 = Vector2(16, 5)
@export_range(2.5, 8.0, 0.1) var cycle_seconds: float = 3.6
@export_range(1.5, 4.0, 0.05) var pulse_seconds: float = 2.65
@export_range(0.0, 8.0, 0.05) var phase_offset: float = 0.28
@export_range(0.3, 0.8, 0.01) var off_brightness: float = 0.46
@export_range(24.0, 60.0, 1.0) var glow_radius: float = 36.0
@export_range(0.0, 0.2, 0.005) var glow_intensity: float = 0.055
@export var glow_color: Color = Color(1.0, 0.09, 0.025, 1.0)
## Enable when the baked lamp is hidden by CanvasModulate.BLACK (the maze).
@export var emissive_lens: bool = false

var _elapsed: float = 0.0
var _pulse: float = 0.0
var _halo_texture: GradientTexture2D
var _background_material: ShaderMaterial
var _lens_texture: ImageTexture
var _lens_offset: Vector2


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = additive
	z_index = 1
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0)])
	_halo_texture = GradientTexture2D.new()
	_halo_texture.width = 128
	_halo_texture.height = 128
	_halo_texture.fill = GradientTexture2D.FILL_RADIAL
	_halo_texture.fill_from = Vector2(0.5, 0.5)
	_halo_texture.fill_to = Vector2(1, 0.5)
	_halo_texture.gradient = gradient
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bind_background()
	if emissive_lens:
		_make_emissive_lens()
	_update_lamps()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_lamps()


func _bind_background() -> void:
	if background_path.is_empty():
		return
	var background := get_node_or_null(background_path) as CanvasItem
	if background == null or not background.material is ShaderMaterial:
		return
	# Each level owns its phase, even if scene materials were shared on disk.
	_background_material = background.material.duplicate() as ShaderMaterial
	background.material = _background_material
	var centers := PackedVector2Array()
	for index in range(4):
		centers.append(baked_lamp_centers[index] if index < baked_lamp_centers.size() else Vector2(-1000, -1000))
	_background_material.set_shader_parameter("warning_lamp_centers", centers)
	_background_material.set_shader_parameter("warning_lamp_count", mini(baked_lamp_centers.size(), 4))
	_background_material.set_shader_parameter("warning_lamp_half_size", lamp_half_size)
	_background_material.set_shader_parameter("warning_lamp_glow_radius", glow_radius)


func _update_lamps() -> void:
	var phase: float = fposmod(_elapsed + phase_offset, maxf(cycle_seconds, 0.1))
	var duration: float = minf(pulse_seconds, cycle_seconds * 0.8)
	# A broad, rounded breath of light. The painted glass never becomes a
	# black hole, and the quiet interval has no abrupt on/off edge.
	var wave: float = sin(PI * phase / duration) if phase < duration else 0.0
	_pulse = smoothstep(0.0, 1.0, wave)
	if _background_material != null:
		_background_material.set_shader_parameter("warning_lamp_brightness", lerpf(off_brightness, 1.0, _pulse))
	queue_redraw()


func _make_emissive_lens() -> void:
	# Reuse this level's painted glass, including its uneven amber filament.
	# Extract only its warm pixels: no wall or metal housing can become a
	# luminous rectangle in the otherwise completely black maze.
	var background := get_node_or_null("../Background") as Sprite2D
	if background == null or background.texture == null or lamp_positions.is_empty():
		return
	var center: Vector2 = lamp_positions[0]
	var half_extent := Vector2i(ceil(lamp_half_size.x + 8.0), ceil(lamp_half_size.y + 8.0))
	var region := Rect2i(Vector2i(center) - half_extent, half_extent * 2)
	var image: Image = background.texture.get_image().get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			var offset := Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(half_extent)
			var shape: float = 1.0 - smoothstep(0.85, 1.45, (offset / (lamp_half_size + Vector2(1.5, 1.5))).length())
			var warm: float = smoothstep(0.08, 0.24, pixel.r - pixel.b)
			var lit: float = smoothstep(0.16, 0.42, pixel.r)
			# An amber-red center retains texture without clipping to white.
			image.set_pixel(x, y, Color(pixel.r * 0.90, pixel.g * 0.58, pixel.b * 0.36, shape * warm * lit))
	_lens_texture = ImageTexture.create_from_image(image)
	_lens_offset = Vector2(region.position) - center


func _draw() -> void:
	if _halo_texture == null:
		return
	for center in lamp_positions:
		var halo_color := glow_color
		halo_color.a = glow_intensity * _pulse
		var halo_extent := Vector2(glow_radius, glow_radius * 0.46)
		draw_texture_rect(_halo_texture, Rect2(center - halo_extent, halo_extent * 2.0), false, halo_color)
		# A second, very close pool of light follows the horizontal glass.
		halo_color.a *= 0.55
		var inner_extent := Vector2(lamp_half_size.x * 1.4, lamp_half_size.y * 1.9)
		draw_texture_rect(_halo_texture, Rect2(center - inner_extent, inner_extent * 2.0), false, halo_color)
		if emissive_lens and _lens_texture != null:
			var lens_alpha: float = lerpf(0.18, 0.86, _pulse)
			draw_texture(_lens_texture, center + _lens_offset, Color(1.0, 1.0, 1.0, lens_alpha))
