extends Node2D
## Первый уровень. Рисунки, персонаж и коллизии находятся в одной системе 1280×720.

@export var respawn_delay: float = 0.65

@onready var player: CharacterBody2D = $Player
@onready var hidden_pit: Node2D = $HiddenPit
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var death_label: Label = $HUD/DeathCount
@onready var status_label: Label = $HUD/Status
@onready var completion_panel: Control = $HUD/Completion
@onready var replay_button: Button = $HUD/Completion/Card/Replay

var deaths: int = 0
var completed: bool = false
var _attempt_id: int = 0


func _ready() -> void:
	player.died.connect(_on_player_died)
	$Exit.body_entered.connect(_on_exit_body_entered)
	replay_button.pressed.connect(restart_level.bind(true))
	restart_level(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()
	elif completed and event.is_action_pressed("ui_accept"):
		restart_level(true)
		get_viewport().set_input_as_handled()


func restart_level(reset_deaths: bool = false) -> void:
	# Invalidates any delayed respawn belonging to the previous attempt.
	_attempt_id += 1
	completed = false
	if reset_deaths:
		deaths = 0
	hidden_pit.reset()
	completion_panel.hide()
	status_label.text = ""
	_update_death_count()
	player.respawn(spawn_point.position)


func _on_player_died() -> void:
	if completed:
		return
	deaths += 1
	_update_death_count()
	status_label.text = "Ещё попытка"
	var attempt_when_died: int = _attempt_id
	await get_tree().create_timer(respawn_delay).timeout
	if is_inside_tree() and attempt_when_died == _attempt_id:
		restart_level()


func _on_exit_body_entered(body: Node2D) -> void:
	if body != player or player.dead or completed:
		return
	completed = true
	player.finish()
	completion_panel.show()
	$HUD/Completion/Card/Result.text = "Уровень пройден!\nСмертей: %d" % deaths
	replay_button.grab_focus()


func _update_death_count() -> void:
	death_label.text = "Смерти: %d" % deaths
