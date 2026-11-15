extends CanvasLayer
## A persistent pause screen keeps controls and sound settings available in-game.

const SETTINGS_SCENE := preload("res://scenes/audio_settings_panel.tscn")

var active: bool = false
var panel: Control
var settings_panel: Control
var resume_button: Button
var settings_button: Button
var menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	get_node("/root/GameSession").scene_transition_started.connect(_on_scene_transition)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "res://scenes/main_menu.tscn":
		return
	if settings_panel.visible:
		settings_panel.close()
	elif active:
		resume_game()
	else:
		pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if active:
		return
	active = true
	get_tree().paused = true
	panel.show()
	resume_button.grab_focus()


func resume_game() -> void:
	settings_panel.close()
	panel.hide()
	active = false
	get_tree().paused = false


func _on_scene_transition(_destination: String) -> void:
	resume_game()


func _build_ui() -> void:
	panel = Control.new()
	panel.name = "PauseScreen"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.01, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 352)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.065, 0.98)
	style.border_color = Color(0.15, 0.42, 0.59)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	card.add_child(rows)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.custom_minimum_size.y = 58
	rows.add_child(title)
	resume_button = _button(rows, "Продолжить")
	settings_button = _button(rows, "Настройки звука")
	menu_button = _button(rows, "Главное меню")
	resume_button.pressed.connect(resume_game)
	menu_button.pressed.connect(_return_to_menu)
	settings_panel = SETTINGS_SCENE.instantiate()
	settings_panel.name = "AudioSettings"
	add_child(settings_panel)
	settings_button.pressed.connect(settings_panel.open)
	panel.hide()


func _button(parent: Node, message: String) -> Button:
	var button := Button.new()
	button.text = message
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.13, 0.19)
	style.border_color = Color(0.15, 0.38, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.23, 0.32)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)
	parent.add_child(button)
	return button


func _return_to_menu() -> void:
	get_node("/root/GameSession").return_to_menu()
