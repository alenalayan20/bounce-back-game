extends StaticBody2D
## Wall geometry for the original 1672 x 941 maze artwork.
## Collision and flashlight occlusion share exactly the same rectangles.

@export var walls: Array[Rect2] = [
	# Outer masonry; the two doorway gaps remain visible and traversable.
	Rect2(31, 24, 36, 886),
	Rect2(1606, 24, 36, 886),
	Rect2(170, 24, 1472, 43),
	Rect2(31, 872, 1468, 38),
	Rect2(1570, 872, 72, 38),
	# Upper-left enclosure and its branches.
	Rect2(175, 161, 225, 40),
	Rect2(175, 161, 39, 194),
	Rect2(175, 316, 532, 40),
	Rect2(513, 49, 38, 307),
	Rect2(333, 337, 39, 167),
	Rect2(667, 337, 40, 170),
	Rect2(490, 469, 217, 41),
	Rect2(490, 469, 40, 189),
	Rect2(175, 619, 355, 41),
	Rect2(65, 470, 153, 40),
	# Upper-middle bend.
	Rect2(653, 160, 216, 40),
	Rect2(830, 160, 39, 195),
	Rect2(830, 313, 180, 43),
	Rect2(970, 334, 40, 176),
	# Upper-right enclosure.
	Rect2(1097, 160, 381, 41),
	Rect2(1097, 160, 41, 184),
	Rect2(1257, 181, 39, 330),
	Rect2(970, 470, 326, 41),
	Rect2(1410, 317, 232, 40),
	Rect2(1410, 337, 40, 170),
	Rect2(1256, 621, 386, 40),
	# Lower-middle enclosure and stems.
	Rect2(816, 470, 40, 189),
	Rect2(816, 619, 340, 41),
	Rect2(1116, 491, 40, 169),
	Rect2(966, 639, 42, 176),
	Rect2(654, 620, 42, 196),
	Rect2(207, 772, 1269, 44),
]

@export var keep_inside_image: bool = true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	for index in range(walls.size()):
		_add_wall(walls[index], "Wall%02d" % (index + 1))
	if keep_inside_image:
		# Door gaps lead to the picture's edge, never to an empty off-map area.
		_add_wall(Rect2(-40, -40, 40, 1021), "BoundsLeft")
		_add_wall(Rect2(1672, -40, 40, 1021), "BoundsRight")
		_add_wall(Rect2(0, -40, 1672, 40), "BoundsTop")
		_add_wall(Rect2(0, 941, 1672, 40), "BoundsBottom")


func get_wall_rects() -> Array[Rect2]:
	return walls.duplicate()


func _add_wall(rect: Rect2, wall_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.name = wall_name + "Collision"
	collider.position = rect.get_center()
	collider.shape = shape
	add_child(collider)

	var polygon := OccluderPolygon2D.new()
	polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
	])
	var occluder := LightOccluder2D.new()
	occluder.name = wall_name + "Occluder"
	occluder.occluder = polygon
	occluder.light_mask = 1
	occluder.occluder_light_mask = 1
	add_child(occluder)
