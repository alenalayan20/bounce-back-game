extends Node2D
## Невидимая точка над полом открывает яму один раз за попытку.

signal activated

@export var trigger_x: float = 1003.0

@onready var cover_shape: CollisionShape2D = $Cover/CollisionShape2D
@onready var artwork: Sprite2D = $OpenArtwork
@onready var trigger: Area2D = $Trigger
@onready var spikes: Area2D = $Spikes

var opened: bool = false


func _ready() -> void:
	trigger.position.x = trigger_x
	trigger.body_entered.connect(_on_trigger_body_entered)
	reset()


func _on_trigger_body_entered(body: Node2D) -> void:
	if body.has_method("die") and not body.get("dead") and not body.get("finished"):
		open_pit()


func open_pit() -> void:
	if opened:
		return
	opened = true
	artwork.show()
	# Area2D emits during physics flushing, so collider changes must be deferred.
	cover_shape.set_deferred("disabled", true)
	spikes.set_deferred("monitoring", true)
	activated.emit()


func reset() -> void:
	opened = false
	artwork.hide()
	cover_shape.set_deferred("disabled", false)
	spikes.set_deferred("monitoring", false)
