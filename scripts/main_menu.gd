extends Control
## The supplied door background and metal buttons form the game's front screen.

const PLAY_ART := preload("res://interface/play.png")
const EXIT_ART := preload("res://interface/exit.png")
const SETTINGS_ART := preload("res://interface/settings.png")
const BACKGROUND_ART := preload("res://interface/door_interface.png")
const SETTINGS_SCENE := preload("res://scenes/audio_settings_panel.tscn")

var play_button: TextureButton
var settings_button: TextureButton
var quit_button: TextureButton
var settings_panel: Control
var language_selector: OptionButton


func _ready() -> void:
	_build_ui()
	Language.language_changed.connect(_refresh_language)
	_refresh_language()
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
	content.size = Vector2(370, 520)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var heading := _label(content, "Title", "PRISON\nBREAK", Vector2(6, 35), Vector2(360, 176), 70, Color(0.94, 0.94, 0.9))
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Bahnschrift", "Arial", "sans-serif"])
	title_font.font_weight = 700
	heading.add_theme_font_override("font", title_font)
	heading.add_theme_constant_override("line_spacing", -12)
	play_button = _image_button(content, "Play", PLAY_ART, Vector2(-7, 194), Vector2(350, 175), "Play")
	play_button.pressed.connect(_start_game)
	quit_button = _image_button(content, "Quit", EXIT_ART, Vector2(53, 361), Vector2(230, 115), "Exit")
	quit_button.pressed.connect(_quit_game)
	settings_button = _image_button(self, "Settings", SETTINGS_ART, Vector2.ZERO, Vector2(72, 72), "Settings")
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -99
	settings_button.offset_top = 24
	settings_button.offset_right = -27
	settings_button.offset_bottom = 96
	language_selector = OptionButton.new()
	language_selector.name = "LanguageSelector"
	language_selector.add_item("EN", 0)
	language_selector.add_item("RU", 1)
	language_selector.add_theme_font_size_override("font_size", 17)
	language_selector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	language_selector.offset_left = -192
	language_selector.offset_top = 40
	language_selector.offset_right = -112
	language_selector.offset_bottom = 80
	add_child(language_selector)
	language_selector.item_selected.connect(_select_language)
	play_button.focus_next = language_selector.get_path()
	language_selector.focus_next = settings_button.get_path()
	language_selector.focus_previous = play_button.get_path()
	settings_button.focus_next = quit_button.get_path()
	quit_button.focus_next = play_button.get_path()
	play_button.focus_previous = quit_button.get_path()
	settings_button.focus_previous = language_selector.get_path()
	quit_button.focus_previous = settings_button.get_path()
	settings_panel = SETTINGS_SCENE.instantiate()
	settings_panel.name = "AudioSettings"
	add_child(settings_panel)
	settings_button.pressed.connect(settings_panel.open)


func _select_language(index: int) -> void:
	Language.set_language("ru" if index == 1 else "en")


func _refresh_language() -> void:
	play_button.tooltip_text = Language.text("play")
	quit_button.tooltip_text = Language.text("exit")
	settings_button.tooltip_text = Language.text("settings")
	language_selector.tooltip_text = Language.text("language")
	language_selector.select(1 if Language.current_code == "ru" else 0)


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
