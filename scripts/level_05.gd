extends Node2D
## The final descent: outrun the rock and cross four one-shot machines.

@export var respawn_delay: float = 0.65
@export var level_number: int = 5

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var boulder: Node2D = $RollingBoulder
@onready var completion_panel: Control = $HUD/Completion
@onready var replay_button: Button = $HUD/Completion/Card/Replay

var deaths: int = 0
var completed: bool = false
var _attempt_id: int = 0
var _transition_pending: bool = false
var _show_retry: bool = false


func _ready() -> void:
	$HUD.layer = 10
	Language.language_changed.connect(_refresh_language)
	player.died.connect(_on_player_died)
	$Exit.body_entered.connect(_on_exit_body_entered)
	replay_button.pressed.connect(continue_level)
	_refresh_language()
	restart_level(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()
	elif completed and event.is_action_pressed("ui_accept"):
		continue_level()
		get_viewport().set_input_as_handled()


func restart_level(reset_deaths: bool = false) -> void:
	_attempt_id += 1
	completed = false
	_transition_pending = false
	_show_retry = false
	if reset_deaths:
		deaths = 0
	for machine in $SurpriseTraps.get_children():
		machine.reset()
	boulder.reset()
	completion_panel.hide()
	_refresh_language()
	player.respawn(spawn_point.global_position)


func _on_player_died() -> void:
	if completed:
		return
	boulder.set_active(false)
	for machine in $SurpriseTraps.get_children():
		machine.set_active(false)
	deaths += 1
	_show_retry = true
	_refresh_language()
	var attempt_when_died: int = _attempt_id
	await get_tree().create_timer(respawn_delay, false).timeout
	if is_inside_tree() and attempt_when_died == _attempt_id:
		restart_level()


func _on_exit_body_entered(body: Node2D) -> void:
	if body != player or player.dead or completed:
		return
	# A late physics event from the previous attempt cannot finish a new run.
	if player.global_position.distance_to($Exit.global_position) > 84.0:
		return
	completed = true
	player.finish()
	boulder.set_active(false)
	for machine in $SurpriseTraps.get_children():
		machine.set_active(false)
	completion_panel.show()
	replay_button.grab_focus()


func continue_level() -> void:
	if not completed or _transition_pending:
		return
	_transition_pending = true
	_return_to_menu.call_deferred()


func _return_to_menu() -> void:
	if completed and _transition_pending:
		get_node("/root/GameSession").return_to_menu()


func _refresh_language() -> void:
	$HUD/LevelTitle.text = Language.text("level_title") % level_number
	$HUD/Controls.text = Language.text("platform_controls")
	$HUD/DeathCount.text = Language.text("deaths") % deaths
	$HUD/Status.text = Language.text("retry_status") if _show_retry else ""
	$HUD/Completion/Card/Result.text = Language.text("game_complete")
	replay_button.text = Language.text("back_to_menu")
