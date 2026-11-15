extends Node
## Every exit reuses the actual level-two painted frame, leaf, controls and lamp.
## Backgrounds are composed in memory; the original artwork stays untouched.

const DOOR_ART: Texture2D = preload("res://art/levels/level_02.png")
const SOURCE_ANCHOR := Vector2(1191, 560)
const SOURCE_LAMP := Vector2(1191, 395)
const PARTS: Array[Rect2i] = [
	Rect2i(1143, 413, 97, 147), # striped frame and door, down to its floor
	Rect2i(1107, 453, 27, 34), # the original little access panel
	Rect2i(1168, 383, 47, 24), # red glass and its metal housing
]

@export_range(1, 4) var level_number: int = 1

static var _textures: Dictionary[int, ImageTexture] = {}


func _ready() -> void:
	var background := get_parent().get_node("Background") as Sprite2D
	var anchor := Vector2(1186, 588)
	var art_scale: float = 1.0
	match level_number:
		2:
			anchor = SOURCE_ANCHOR
		3:
			anchor = Vector2(1175, 524)
		4:
			anchor = Vector2(1534, 900)
			art_scale = 0.62
	if level_number != 2:
		if not _textures.has(level_number):
			var original: Image = background.texture.get_image()
			original.convert(Image.FORMAT_RGBA8)
			var composed: Image = original.duplicate()
			_clear_old_exit(composed, original)
			var source: Image = DOOR_ART.get_image()
			source.convert(Image.FORMAT_RGBA8)
			_paint_lamp_spill(composed, source, anchor, art_scale)
			for part in PARTS:
				_paint_part(composed, source, part, anchor, art_scale)
			_textures[level_number] = ImageTexture.create_from_image(composed)
		background.texture = _textures[level_number]
	# The former level-one magnifier must not distort the shared painted door.
	if background.material is ShaderMaterial:
		(background.material as ShaderMaterial).set_shader_parameter("door_scale", 1.0)
	var warning := get_parent().get_node("DoorWarningLights")
	var lamp: Vector2 = anchor + (SOURCE_LAMP - SOURCE_ANCHOR) * art_scale
	warning.lamp_positions = PackedVector2Array([lamp])
	warning.baked_lamp_centers = PackedVector2Array([lamp]) if level_number != 4 else PackedVector2Array()
	warning.lamp_half_size = Vector2(18, 5) * art_scale
	warning.glow_radius = 36.0 * art_scale


func _clear_old_exit(image: Image, original: Image) -> void:
	match level_number:
		1:
			_remove_red_spill(image, original, Rect2i(1115, 445, 143, 143))
			_clone_wall(image, original, Rect2i(1151, 501, 72, 87), Vector2i(-180, 0), 3.0)
			_heal_brick_rows(image, Rect2i(1119, 521, 33, 34), 4.0)
			_clone_wall(image, original, Rect2i(1166, 477, 40, 22), Vector2i(-130, 0), 3.0)
		3:
			_remove_red_spill(image, original, Rect2i(1101, 326, 154, 198))
			_heal_brick_rows(image, Rect2i(1119, 383, 111, 141), 4.0)
			_heal_brick_rows(image, Rect2i(1083, 431, 37, 48), 4.0)
			_heal_brick_rows(image, Rect2i(1141, 350, 66, 39), 4.0)
		4:
			# Rebuild only the old arrow tile and the old lamp, using nearby
			# floor tiles on the same 30px grid. The masonry jambs stay intact.
			_heal_floor_fixture(image, original, Rect2i(1507, 765, 55, 35))
			for y in range(800, 911):
				for x in range(1500, 1570):
					var source_y: int = 709 + posmod(y - 799, 30)
					var edge: float = minf(x - 1499.5, 1570.5 - x)
					var alpha: float = smoothstep(0.0, 3.0, edge)
					var floor_pixel: Color = original.get_pixel(x, source_y)
					# Retain the nearby red reflection; the replacement lamp is
					# only 17px below the old one and lights this same floor.
					floor_pixel.r += 0.055
					floor_pixel.g += 0.006
					image.set_pixel(x, y, image.get_pixel(x, y).lerp(floor_pixel, alpha))


func _remove_red_spill(image: Image, original: Image, region: Rect2i) -> void:
	# Keep this level's own brick relief and mortar. Only the warm reflected
	# emission from the replaced lamp is removed, with no rectangular patch.
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var pixel: Color = original.get_pixel(x, y)
			var warm: float = smoothstep(0.025, 0.15, pixel.r - pixel.b)
			var clean := Color(minf(pixel.r, pixel.b * 0.72), minf(pixel.g, pixel.b * 0.87), pixel.b, pixel.a)
			image.set_pixel(x, y, pixel.lerp(clean, warm))


func _clone_wall(image: Image, original: Image, region: Rect2i, offset: Vector2i, feather: float) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var edge: float = minf(minf(x - region.position.x + 0.5, region.end.x - x - 0.5), minf(y - region.position.y + 0.5, region.end.y - y - 0.5))
			var alpha: float = smoothstep(0.0, feather, edge)
			var clean: Color = original.get_pixel(x + offset.x, y + offset.y)
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(clean, alpha))


func _heal_brick_rows(image: Image, region: Rect2i, feather: float) -> void:
	# These backgrounds have continuous horizontal mortar courses. Extend
	# the neighboring clean course across a removed fitting, avoiding the
	# brightness seams caused by copying a distant, differently lit wall.
	for y in range(region.position.y, region.end.y):
		var left: Color = image.get_pixel(region.position.x - 1, y)
		var right: Color = image.get_pixel(region.end.x, y)
		for x in range(region.position.x, region.end.x):
			var weight: float = float(x - region.position.x + 1) / float(region.size.x + 1)
			var edge: float = minf(y - region.position.y + 0.5, region.end.y - y - 0.5)
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(left.lerp(right, weight), smoothstep(0.0, feather, edge)))


func _heal_floor_fixture(image: Image, original: Image, region: Rect2i) -> void:
	# Match both the floor grid and the surrounding painted red reflection.
	# Sampling two tiles above supplies the texture relief; only its broad
	# lighting is adjusted to the clean neighbors beside the removed lamp.
	for y in range(region.position.y, region.end.y):
		var left: Color = original.get_pixel(region.position.x - 2, y)
		var right: Color = original.get_pixel(region.end.x + 2, y)
		var source_left: Color = original.get_pixel(region.position.x - 2, y - 60)
		var source_right: Color = original.get_pixel(region.end.x + 2, y - 60)
		for x in range(region.position.x, region.end.x):
			var weight: float = float(x - region.position.x + 2) / float(region.size.x + 4)
			var clean: Color = original.get_pixel(x, y - 60) + left.lerp(right, weight) - source_left.lerp(source_right, weight)
			clean = clean.clamp(Color(0, 0, 0, 1), Color.WHITE)
			var edge: float = minf(minf(x - region.position.x + 0.5, region.end.x - x - 0.5), minf(y - region.position.y + 0.5, region.end.y - y - 0.5))
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(clean, smoothstep(0.0, 3.0, edge)))


func _paint_lamp_spill(image: Image, source: Image, anchor: Vector2, art_scale: float) -> void:
	# Reuse the source lamp's soft warm reflection as emission, while keeping
	# each destination's own brick/floor texture beneath it.
	var center: Vector2 = anchor + (SOURCE_LAMP - SOURCE_ANCHOR) * art_scale
	var radius: int = ceili(78.0 * art_scale)
	for y in range(floori(center.y) - radius, floori(center.y) + radius + 1):
		for x in range(floori(center.x) - radius, floori(center.x) + radius + 1):
			var source_point: Vector2i = Vector2i((SOURCE_LAMP + (Vector2(x, y) - center) / art_scale).round())
			var painted: Color = source.get_pixelv(source_point)
			var distance: float = ((Vector2(x, y) - center) / (78.0 * art_scale)).length()
			var amount: float = maxf(painted.r - painted.b * 0.8, 0.0) * (1.0 - smoothstep(0.5, 1.0, distance))
			var target: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(minf(target.r + amount * 0.65, 1.0), minf(target.g + amount * 0.07, 1.0), target.b, target.a))


func _paint_part(image: Image, source: Image, region: Rect2i, anchor: Vector2, art_scale: float) -> void:
	var part: Image = source.get_region(region)
	for y in range(part.get_height()):
		for x in range(part.get_width()):
			var pixel: Color = part.get_pixel(x, y)
			var edge: float = minf(minf(x + 0.5, part.get_width() - x - 0.5), minf(y + 0.5, part.get_height() - y - 0.5))
			# A couple of soft edge pixels keep the frame's painted silhouette.
			pixel.a *= smoothstep(0.0, 1.6, edge)
			part.set_pixel(x, y, pixel)
	if not is_equal_approx(art_scale, 1.0):
		part.resize(roundi(part.get_width() * art_scale), roundi(part.get_height() * art_scale), Image.INTERPOLATE_LANCZOS)
	var destination := Vector2i((anchor + (Vector2(region.position) - SOURCE_ANCHOR) * art_scale).round())
	image.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), destination)
