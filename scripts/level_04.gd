extends Node2D
## Top-down maze: reaching the exit opens the fifth round.

@export_file("*.tscn") var next_level_path: String = "res://scenes/level_05.tscn"

@onready var player: CharacterBody2D = $Player
@onready var flashlight: Node2D = $Flashlight
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var completion_panel: Control = $HUD/Completion
@onready var replay_button: Button = $HUD/Completion/Card/Replay

var level_number: int = 4
var completed: bool = false
var _return_pending: bool = false


func _ready() -> void:
	$HUD.layer = 10
	Language.language_changed.connect(_refresh_language)
	$HUD/DeathCount.hide()
	$HUD/Status.text = ""
	_refresh_language()
	replay_button.pressed.connect(continue_level)
	$Exit.body_entered.connect(_on_exit_body_entered)
	player.died.connect(restart_level)
	flashlight.set_target(player)
	restart_level()


func _refresh_language() -> void:
	$HUD/LevelTitle.text = Language.text("level_title") % level_number
	$HUD/Controls.text = Language.text("maze_controls")
	$HUD/Completion/Card/Result.text = Language.text("level_complete_short") % level_number
	replay_button.text = Language.text("next_level") % 5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()
	elif completed and event.is_action_pressed("ui_accept"):
		continue_level()
		get_viewport().set_input_as_handled()


func restart_level(_reset_deaths: bool = false) -> void:
	completed = false
	_return_pending = false
	completion_panel.hide()
	player.respawn(spawn_point.global_position)
	flashlight.set_target(player)


func _on_exit_body_entered(body: Node2D) -> void:
	if body != player or completed or player.dead:
		return
	# Ignore an old physics event if R teleported the hero back to the entrance.
	if player.global_position.distance_to($Exit.global_position) > 72.0:
		return
	completed = true
	player.finish()
	completion_panel.show()
	replay_button.grab_focus()


func continue_level() -> void:
	if not completed or _return_pending:
		return
	_return_pending = true
	_load_next_level.call_deferred()


func _load_next_level() -> void:
	if completed and _return_pending:
		get_node("/root/GameSession").change_scene(next_level_path)
