extends Node2D
## Общие правила уровня: попытки, ловушки, выход и переход к следующей карте.

@export var respawn_delay: float = 0.65
@export var level_number: int = 1
@export_file("*.tscn") var next_level_path: String = ""

@onready var player: CharacterBody2D = $Player
@onready var hidden_pit = get_node_or_null("HiddenPit")
@onready var trap = get_node_or_null("SurpriseSpikes")
@onready var moving_saw = get_node_or_null("MovingSaw")
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var death_label: Label = $HUD/DeathCount
@onready var status_label: Label = $HUD/Status
@onready var completion_panel: Control = $HUD/Completion
@onready var replay_button: Button = $HUD/Completion/Card/Replay

var deaths: int = 0
var completed: bool = false
var _attempt_id: int = 0
var _transition_pending: bool = false


func _ready() -> void:
	$HUD/LevelTitle.text = "УРОВЕНЬ %02d  /  БЛОК А-1" % level_number
	player.died.connect(_on_player_died)
	$Exit.body_entered.connect(_on_exit_body_entered)
	replay_button.pressed.connect(continue_level)
	replay_button.text = "Уровень %d  ↵" % (level_number + 1) if not next_level_path.is_empty() else "Ещё раз  ↵"
	restart_level(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()
		get_viewport().set_input_as_handled()
	elif completed and event.is_action_pressed("ui_accept"):
		continue_level()
		get_viewport().set_input_as_handled()


func restart_level(reset_deaths: bool = false) -> void:
	# Invalidates any delayed respawn belonging to the previous attempt.
	_attempt_id += 1
	completed = false
	_transition_pending = false
	if reset_deaths:
		deaths = 0
	if hidden_pit != null:
		hidden_pit.reset()
	if trap != null:
		trap.reset()
	if moving_saw != null:
		moving_saw.reset()
	completion_panel.hide()
	status_label.text = ""
	_update_death_count()
	player.respawn(spawn_point.position)


func continue_level() -> void:
	if not completed or _transition_pending:
		return
	if next_level_path.is_empty():
		restart_level(true)
		return
	# Defer replacing the scene until the current input callback has returned.
	_transition_pending = true
	_load_next_level.call_deferred()


func _load_next_level() -> void:
	if not completed or not _transition_pending:
		return
	var result := get_tree().change_scene_to_file(next_level_path)
	if result != OK:
		_transition_pending = false
		status_label.text = "Не удалось открыть следующий уровень"
		push_error("Could not open level: %s (error %d)" % [next_level_path, result])


func _on_player_died() -> void:
	if completed:
		return
	if moving_saw != null:
		moving_saw.set_active(false)
	deaths += 1
	_update_death_count()
	status_label.text = "Ещё попытка"
	var attempt_when_died: int = _attempt_id
	await get_tree().create_timer(respawn_delay, false).timeout
	if is_inside_tree() and attempt_when_died == _attempt_id:
		restart_level()


func _on_exit_body_entered(body: Node2D) -> void:
	if body != player or player.dead or completed:
		return
	completed = true
	player.finish()
	if moving_saw != null:
		moving_saw.set_active(false)
	completion_panel.show()
	$HUD/Completion/Card/Result.text = "Уровень %d пройден!\nСмертей: %d" % [level_number, deaths]
	replay_button.grab_focus()


func _update_death_count() -> void:
	death_label.text = "Смерти: %d" % deaths
