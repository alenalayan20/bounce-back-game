extends Node2D
## Readable, soft steam from the pipe mouths; the original artwork stays intact.

@export_range(3.0, 12.0, 0.1) var cycle_seconds: float = 5.0
@export_range(0.0, 1.0, 0.01) var steam_opacity: float = 0.52

var elapsed_time: float = 0.0


func _process(delta: float) -> void:
	elapsed_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_steam(Vector2(384.0, 112.0), 1.0, 0.0)
	_draw_steam(Vector2(350.0, 312.0), -1.0, 1.7)
	draw_set_transform(Vector2.ZERO)


func _draw_steam(origin: Vector2, direction: float, phase: float) -> void:
	for puff in range(4):
		var age: float = fposmod(elapsed_time + phase + puff * cycle_seconds / 4.0, cycle_seconds) / cycle_seconds
		# A smooth fade hides the wrap at the pipe mouth and the end of each wisp.
		var envelope: float = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.50, 1.0, age))
		var drift := Vector2(
			direction * (2.0 + 46.0 * age) + sin(age * TAU + float(puff)) * 3.0,
			-2.0 - 42.0 * age
		)
		var radius: float = lerpf(5.0, 17.0, age)
		var tint := Color(0.65, 0.74, 0.80, steam_opacity * envelope)
		# Feathered lobes overlap into a continuous plume without visible outlines.
		_draw_soft_wisp(origin + drift, radius, tint, age * 0.5)
		_draw_soft_wisp(origin + drift + Vector2(direction * radius * 0.65, -radius * 0.3), radius * 0.7, Color(tint, tint.a * 0.55), -age * 0.4)


func _draw_soft_wisp(at: Vector2, radius: float, tint: Color, angle: float) -> void:
	draw_set_transform(at, angle, Vector2(1.40, 0.8))
	for layer in range(10):
		var fraction: float = float(layer) / 9.0
		var layer_radius: float = radius * lerpf(1.65, 0.20, fraction)
		var layer_alpha: float = tint.a * lerpf(0.018, 0.095, fraction)
		draw_circle(Vector2.ZERO, layer_radius, Color(tint, layer_alpha), true, -1.0, true)
