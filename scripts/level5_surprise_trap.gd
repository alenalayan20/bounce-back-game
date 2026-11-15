extends Node2D
## A one-shot machine trap. Only the moving metal/teeth have lethal shapes.

enum Kind { HATCH, SPIKES, PRESS }
enum Phase { ARMED, WARNING, EXTENDING, HOLDING, RETRACTING, SPENT }

@export var kind: Kind = Kind.SPIKES
@export var width: float = 58.0
@export var spike_height: float = 22.0
@export var tooth_count: int = 2
@export var trigger_rect := Rect2(-120.0, -76.0, 50.0, 82.0)
@export var warning_time: float = 0.28
@export var extend_time: float = 0.12
@export var hold_time: float = 1.25
@export var retract_time: float = 0.22
@export var press_travel: float = 94.0

var phase: Phase = Phase.ARMED
var active: bool = true
var _elapsed: float = 0.0
var _extension: float = 0.0
var _lethal: bool = false
var _hazard: Area2D
var _teeth: Array[CollisionPolygon2D] = []
var _press_shape: CollisionShape2D
var _hatch_shape: CollisionShape2D
var _player: CharacterBody2D


func _ready() -> void:
	_hazard = Area2D.new()
	_hazard.collision_layer = 0
	_hazard.collision_mask = 2
	_hazard.monitorable = false
	add_child(_hazard)
	_hazard.body_entered.connect(_on_body_entered)
	if kind == Kind.PRESS:
		_press_shape = CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(width, 32.0)
		_press_shape.shape = rectangle
		_press_shape.disabled = true
		_hazard.add_child(_press_shape)
	else:
		for index in range(tooth_count):
			var triangle := CollisionPolygon2D.new()
			triangle.disabled = true
			_hazard.add_child(triangle)
			_teeth.append(triangle)
	if kind == Kind.HATCH:
		var floor_body := StaticBody2D.new()
		floor_body.collision_layer = 1
		floor_body.collision_mask = 2
		add_child(floor_body)
		_hatch_shape = CollisionShape2D.new()
		var floor_shape := RectangleShape2D.new()
		floor_shape.size = Vector2(width, 25.0)
		_hatch_shape.shape = floor_shape
		_hatch_shape.position.y = 12.5
		floor_body.add_child(_hatch_shape)
	reset()


func reset() -> void:
	phase = Phase.ARMED
	active = true
	_elapsed = 0.0
	_extension = 0.0
	_lethal = false
	if _hatch_shape != null:
		_hatch_shape.set_deferred("disabled", false)
	_update_shapes()
	queue_redraw()


func set_active(enabled: bool) -> void:
	active = enabled
	if not active:
		_lethal = false
		_set_hazard_enabled(false)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(_player) or _player.dead or _player.finished:
		return
	if phase == Phase.ARMED:
		if trigger_rect.has_point(to_local(_player.global_position)):
			phase = Phase.WARNING
			_elapsed = 0.0
		queue_redraw()
		return
	if phase == Phase.SPENT:
		return
	_elapsed += delta
	match phase:
		Phase.WARNING:
			if _elapsed >= warning_time:
				phase = Phase.EXTENDING
				_elapsed = 0.0
				if kind == Kind.HATCH:
					_hatch_shape.set_deferred("disabled", true)
		Phase.EXTENDING:
			_extension = minf(_elapsed / maxf(extend_time, 0.01), 1.0)
			if _extension >= 1.0:
				phase = Phase.HOLDING
				_elapsed = 0.0
		Phase.HOLDING:
			_extension = 1.0
			if _elapsed >= hold_time:
				phase = Phase.RETRACTING
				_elapsed = 0.0
		Phase.RETRACTING:
			_extension = 1.0 - minf(_elapsed / maxf(retract_time, 0.01), 1.0)
			if _extension <= 0.0:
				phase = Phase.SPENT
				if kind == Kind.HATCH:
					_hatch_shape.set_deferred("disabled", false)
	_update_shapes()
	if _lethal:
		for body in _hazard.get_overlapping_bodies():
			_on_body_entered(body)
	queue_redraw()


func _update_shapes() -> void:
	_lethal = active and _extension > 0.08
	if kind == Kind.PRESS:
		_press_shape.position = Vector2(0.0, -press_travel - 16.0 + press_travel * _extension)
	else:
		var base_y: float = 25.0 if kind == Kind.HATCH else 0.0
		var visible_height: float = spike_height if kind == Kind.HATCH else spike_height * _extension
		var tooth_width: float = width / tooth_count
		for index in range(_teeth.size()):
			var left: float = -width * 0.5 + index * tooth_width + 2.0
			var right: float = left + tooth_width - 4.0
			_teeth[index].set_deferred("polygon", PackedVector2Array([
				Vector2(left, base_y), Vector2((left + right) * 0.5, base_y - maxf(visible_height, 0.05)), Vector2(right, base_y)
			]))
	_set_hazard_enabled(_lethal)


func _set_hazard_enabled(enabled: bool) -> void:
	if _press_shape != null:
		_press_shape.set_deferred("disabled", not enabled)
	for triangle in _teeth:
		triangle.set_deferred("disabled", not enabled)


func _on_body_entered(body: Node2D) -> void:
	if active and _lethal and body.is_in_group("player") and body.has_method("die"):
		body.die()


func _draw() -> void:
	var warning: bool = phase == Phase.WARNING
	var glow: float = 0.4 + sin(_elapsed * 28.0) * 0.3 if warning else 0.12
	var metal := Color(0.26, 0.29, 0.33)
	var edge := Color(0.69, 0.65, 0.49)
	if kind == Kind.PRESS:
		var block_y: float = -press_travel - 32.0 + press_travel * _extension
		draw_rect(Rect2(-width * 0.5 - 4.0, -press_travel - 35.0, width + 8.0, 8.0), Color(0.07, 0.09, 0.12))
		draw_line(Vector2(-width * 0.28, -press_travel - 28.0), Vector2(-width * 0.28, block_y), metal, 5.0)
		draw_line(Vector2(width * 0.28, -press_travel - 28.0), Vector2(width * 0.28, block_y), metal, 5.0)
		draw_rect(Rect2(-width * 0.5, block_y, width, 32.0), Color(0.11, 0.13, 0.16))
		draw_rect(Rect2(-width * 0.5, block_y, width, 32.0), metal, false, 2.0)
		for index in range(4):
			var stripe_x: float = -width * 0.5 + index * 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(stripe_x, block_y + 22.0), Vector2(stripe_x + 7.0, block_y + 22.0), Vector2(stripe_x + 1.0, block_y + 31.0), Vector2(stripe_x - 6.0, block_y + 31.0)]), Color(0.56, 0.36, 0.06))
		draw_circle(Vector2(0.0, -press_travel - 32.0), 3.0, Color(0.85, 0.23, 0.03, glow + 0.25))
		return
	if kind == Kind.HATCH and _extension > 0.0:
		draw_rect(Rect2(-width * 0.5, -1.0, width, 27.0), Color(0.014, 0.024, 0.038))
		draw_line(Vector2(-width * 0.5, 0.0), Vector2(-width * 0.5, 25.0), edge, 2.0)
		draw_line(Vector2(width * 0.5, 0.0), Vector2(width * 0.5, 25.0), edge, 2.0)
	if kind == Kind.SPIKES:
		draw_rect(Rect2(-width * 0.5, 1.0, width, 5.0), Color(0.055, 0.07, 0.09))
	if _extension > 0.0:
		var base_y: float = 25.0 if kind == Kind.HATCH else 0.0
		var visible_height: float = spike_height if kind == Kind.HATCH else spike_height * _extension
		var tooth_width: float = width / tooth_count
		for index in range(tooth_count):
			var left: float = -width * 0.5 + index * tooth_width + 2.0
			var right: float = left + tooth_width - 4.0
			var tip := Vector2((left + right) * 0.5, base_y - visible_height)
			draw_colored_polygon(PackedVector2Array([Vector2(left, base_y), tip, Vector2(right, base_y)]), metal)
			draw_line(Vector2(left, base_y), tip, Color(0.75, 0.76, 0.73), 1.5)
			draw_line(tip, Vector2(right, base_y), Color(0.36, 0.28, 0.25), 1.0)
	if warning:
		draw_line(Vector2(-width * 0.5, 1.0), Vector2(width * 0.5, 1.0), Color(1.0, 0.19, 0.025, glow + 0.25), 3.0)
