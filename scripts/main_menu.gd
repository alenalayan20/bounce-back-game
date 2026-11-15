extends Control
## The supplied door background and metal buttons form the game's front screen.

const PLAY_ART := preload("res://interface/play.png")
const SETTINGS_ART := preload("res://interface/settings.png")
const BACKGROUND_ART := preload("res://interface/door_interface.png")
const SETTINGS_SCENE := preload("res://scenes/audio_settings_panel.tscn")

var play_button: TextureButton
var settings_button: TextureButton
var quit_button: Button
var settings_panel: Control


func _ready() -> void:
	_build_ui()
	get_node("/root/GameSession").play_menu_music()
	play_button.grab_focus.call_deferred()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.name = "DoorBackground"
	background.texture = BACKGROUND_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var content := Control.new()
	content.name = "MenuContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	content.position = Vector2(88, -204)
	content.size = Vector2(370, 450)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_label(content, "Episode", "ПОБЕГ ИЗ БЛОКА А-1", Vector2(10, 0), Vector2(350, 24), 14, Color(0.64, 0.69, 0.73))
	var heading := _label(content, "Title", "BOUNCE\nBACK", Vector2(6, 35), Vector2(360, 176), 70, Color(0.94, 0.94, 0.9))
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Bahnschrift", "Arial", "sans-serif"])
	title_font.font_weight = 700
	heading.add_theme_font_override("font", title_font)
	heading.add_theme_constant_override("line_spacing", -12)
	_label(content, "Tagline", "ЧЕТЫРЕ УРОВНЯ. ОДИН ВЫХОД.", Vector2(10, 210), Vector2(350, 24), 13, Color(0.56, 0.62, 0.66))
	play_button = _image_button(content, "Play", PLAY_ART, Vector2(-7, 242), Vector2(350, 175), "Играть")
	play_button.pressed.connect(_start_game)
	var play_caption := _label(content, "PlayCaption", "ИГРАТЬ", Vector2(0, 410), Vector2(336, 25), 17, Color(0.8, 0.88, 0.93))
	play_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_button = Button.new()
	quit_button.name = "Quit"
	quit_button.text = "Выйти"
	quit_button.position = Vector2(104, 448)
	quit_button.size = Vector2(130, 36)
	quit_button.add_theme_font_size_override("font_size", 17)
	quit_button.add_theme_color_override("font_color", Color(0.58, 0.64, 0.68))
	quit_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]:
		quit_button.add_theme_stylebox_override(state, empty)
	content.add_child(quit_button)
	quit_button.pressed.connect(_quit_game)
	settings_button = _image_button(self, "Settings", SETTINGS_ART, Vector2.ZERO, Vector2(72, 72), "Настройки")
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -99
	settings_button.offset_top = 24
	settings_button.offset_right = -27
	settings_button.offset_bottom = 96
	var controls := _label(self, "ControlsHint", "A / D и стрелки — движение · W / ↑ — прыжок\nВ лабиринте — W A S D · Esc — пауза", Vector2.ZERO, Vector2(660, 52), 14, Color(0.43, 0.49, 0.53))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 98
	controls.offset_top = -76
	controls.offset_right = 758
	controls.offset_bottom = -24
	play_button.focus_next = settings_button.get_path()
	settings_button.focus_next = quit_button.get_path()
	quit_button.focus_next = play_button.get_path()
	play_button.focus_previous = quit_button.get_path()
	settings_button.focus_previous = play_button.get_path()
	quit_button.focus_previous = settings_button.get_path()
	settings_panel = SETTINGS_SCENE.instantiate()
	settings_panel.name = "AudioSettings"
	add_child(settings_panel)
	settings_button.pressed.connect(settings_panel.open)


func _image_button(parent: Node, node_name: String, texture: Texture2D, at: Vector2, dimensions: Vector2, hint: String) -> TextureButton:
	var button := TextureButton.new()
	button.name = node_name
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.position = at
	button.size = dimensions
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_ALL
	var mask := BitMap.new()
	mask.create_from_image_alpha(texture.get_image(), 0.12)
	button.texture_click_mask = mask
	parent.add_child(button)
	button.mouse_entered.connect(_highlight.bind(button, true))
	button.mouse_exited.connect(_highlight.bind(button, false))
	button.focus_entered.connect(_highlight.bind(button, true))
	button.focus_exited.connect(_highlight.bind(button, false))
	button.button_down.connect(_press_visual.bind(button, true))
	button.button_up.connect(_press_visual.bind(button, false))
	return button


func _highlight(button: TextureButton, highlighted: bool) -> void:
	button.self_modulate = Color(1.12, 1.12, 1.12) if highlighted or button.has_focus() else Color.WHITE


func _press_visual(button: TextureButton, pressed: bool) -> void:
	button.self_modulate = Color(0.76, 0.86, 0.94) if pressed else Color(1.1, 1.1, 1.1)


func _label(parent: Node, node_name: String, message: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = message
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _start_game() -> void:
	play_button.disabled = true
	get_node("/root/GameSession").start_game()


func _quit_game() -> void:
	get_node("/root/GameSession").stop_menu_music(false)
	get_tree().quit()
