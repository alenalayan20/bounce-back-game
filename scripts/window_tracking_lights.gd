extends Node2D
## Small stationary window glows, with a slow idle pulse.

@export var window_origins: PackedVector2Array = PackedVector2Array([Vector2(244, 267), Vector2(633, 267), Vector2(973, 267)])
@export_range(0.0, 0.2, 0.005) var intensity: float = 0.10
@export_range(0.0, 0.3, 0.01) var pulse_amount: float = 0.18
@export_range(3.0, 12.0, 0.1) var cycle_seconds: float = 6.5

var _elapsed: float = 0.0
var _lights: Array[PointLight2D] = []


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(0.3, 0.3, 0.3, 1), Color.BLACK])
	var texture := GradientTexture2D.new()
	texture.width = 144
	texture.height = 144
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	for i in range(window_origins.size()):
		var glow := PointLight2D.new()
		glow.name = "WindowGlow%d" % (i + 1)
		glow.position = window_origins[i] + Vector2(0, 14)
		glow.texture = texture
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.color = Color(0.28, 0.65, 1.0)
		glow.energy = intensity
		glow.shadow_enabled = false
		add_child(glow)
		_lights.append(glow)


func _process(delta: float) -> void:
	_elapsed += delta
	for i in range(_lights.size()):
		_lights[i].energy = intensity * (1.0 + pulse_amount * sin(_elapsed * TAU / cycle_seconds + float(i) * 1.7))
