extends Sprite2D
## The painted map stays intact on disk. Remove its stationary boulder only
## in the display texture, so the separate animated rock is the sole boulder.

func _ready() -> void:
	var source: Image = texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var composed: Image = source.duplicate()
	var center := Vector2(153.0, 155.0)
	for y in range(81, 230):
		for x in range(79, 221):
			var distance: float = Vector2(x, y).distance_to(center)
			# Preserve every pixel of the slope's warm rim and masonry.
			var ramp_y: float = 116.0 + 114.0 * float(x) / 190.0
			if distance > 73.0 or y >= ramp_y - 3.0:
				continue
			var alpha: float = (1.0 - smoothstep(58.0, 73.0, distance)) * (1.0 - smoothstep(214.0, 221.0, float(x)))
			# Reuse nearby brick relief and match the surrounding lighting.
			# Below y=165 the left sample reaches the bright slope: blend
			# over to the clean right wall before it can create a streak.
			var lower_row: float = smoothstep(148.0, 164.0, float(y))
			var target_right: Color = source.get_pixel(216, y)
			var source_right: Color = source.get_pixel(396, y)
			var target_left: Color = source.get_pixel(90, y).lerp(target_right, lower_row)
			var source_left: Color = source.get_pixel(270, y).lerp(source_right, lower_row)
			var weight: float = float(x - 90) / 126.0
			var wall: Color = source.get_pixel(x + 180, y) + target_left.lerp(target_right, weight) - source_left.lerp(source_right, weight)
			wall = wall.clamp(Color(0, 0, 0, 1), Color.WHITE)
			composed.set_pixel(x, y, source.get_pixel(x, y).lerp(wall, alpha))
	texture = ImageTexture.create_from_image(composed)
