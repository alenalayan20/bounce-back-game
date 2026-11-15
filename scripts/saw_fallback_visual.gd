extends Node2D
## A temporary code-drawn blade; replaced automatically by supplied artwork.

func _draw() -> void:
	var teeth := PackedVector2Array()
	for tooth in range(30):
		var angle: float = TAU * float(tooth) / 30.0
		teeth.append(Vector2.from_angle(angle) * 23.0)
		teeth.append(Vector2.from_angle(angle + 0.065) * 28.0)
		teeth.append(Vector2.from_angle(angle + 0.12) * 27.0)
		teeth.append(Vector2.from_angle(angle + 0.17) * 23.0)
	draw_colored_polygon(teeth, Color(0.47, 0.62, 0.69))
	var outline := teeth.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color(0.72, 0.83, 0.85), 1.0, true)
	draw_circle(Vector2.ZERO, 21.0, Color(0.13, 0.23, 0.30), true, -1.0, true)
	draw_arc(Vector2.ZERO, 18.5, 0.0, TAU, 48, Color(0.36, 0.49, 0.55), 1.4, true)
	for notch in range(5):
		var angle: float = TAU * float(notch) / 5.0
		draw_line(Vector2.from_angle(angle) * 11.0, Vector2.from_angle(angle + 0.13) * 17.0, Color(0.06, 0.12, 0.18), 2.5, true)
	draw_circle(Vector2.ZERO, 7.0, Color(0.43, 0.56, 0.57), true, -1.0, true)
	draw_circle(Vector2.ZERO, 3.0, Color(0.08, 0.15, 0.20), true, -1.0, true)
