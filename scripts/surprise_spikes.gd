extends Node2D
## Two hidden spikes in the centre; the outer ends of the platform stay safe.

signal activated

@export_range(0.05, 0.3, 0.01) var rise_time: float = 0.10

@onready var danger: Area2D = $Danger
@onready var visual: Node2D = $Visual

var opened: bool = false
var _rise_tween: Tween


func _ready() -> void:
	$LandingTrigger.body_entered.connect(_on_landing_trigger_entered)
	$CenterTrigger.body_entered.connect(_on_center_trigger_entered)
	danger.body_entered.connect(_on_danger_body_entered)
	reset()


func _is_live_player(body: Node2D) -> bool:
	return body.has_method("die") and not body.get("dead") and not body.get("finished")


func _on_landing_trigger_entered(body: Node2D) -> void:
	if not _is_live_player(body):
		return
	var feet := to_local(body.global_position)
	# A body coming up from underneath can overlap with its head. Only feet
	# beside the platform surface count as landing/stepping onto this trigger.
	if feet.y >= -8.0 and feet.y <= 6.0 and absf(feet.x) <= 82.0:
		activate()


func _on_center_trigger_entered(body: Node2D) -> void:
	if _is_live_player(body) and to_local(body.global_position).y <= 6.0:
		activate()


func activate() -> void:
	if opened:
		return
	opened = true
	visual.show()
	visual.scale.y = 0.001
	danger.scale.y = 0.001
	danger.set_deferred("monitoring", true)
	# The two collision triangles rise with the picture. There is no invisible
	# full-height hazard while the spikes are still beneath the platform.
	_rise_tween = create_tween().set_parallel(true)
	_rise_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_rise_tween.tween_property(visual, "scale:y", 1.0, rise_time)
	_rise_tween.tween_property(danger, "scale:y", 1.0, rise_time)
	activated.emit()


func reset() -> void:
	if _rise_tween != null and _rise_tween.is_valid():
		_rise_tween.kill()
	opened = false
	visual.hide()
	visual.scale.y = 0.001
	danger.scale.y = 0.001
	danger.set_deferred("monitoring", false)


func _on_danger_body_entered(body: Node2D) -> void:
	if opened and _is_live_player(body):
		body.die()
