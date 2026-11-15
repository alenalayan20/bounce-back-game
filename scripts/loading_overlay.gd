extends CanvasLayer
## A black transition screen with the existing runner looping in place.

signal display_finished

const RUNNER_FRAMES := preload("res://resources/side_frames.tres")
const MINIMUM_DISPLAY_SECONDS: float = 0.7

var active: bool = false
var progress: float = 0.0
var target_progress: float = 0.0
var _elapsed: float = 0.0
var _display_finished: bool = false
var _screen: Control
var _content: Control
var _runner: AnimatedSprite2D
var _loading_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build_ui()
	var language := get_node_or_null("/root/Language")
	if language != null:
		language.language_changed.connect(_update_language)
	_update_language()
	hide()
	set_process_input(false)


func begin() -> void:
	active = true
	progress = 0.0
	target_progress = 0.0
	_elapsed = 0.0
	_display_finished = false
	_runner.play(&"run")
	set_process_input(true)
	show()


func set_progress(value: float) -> void:
	target_progress = maxf(target_progress, clampf(value, 0.0, 1.0))


func can_finish() -> bool:
	return active and progress >= 1.0 and _elapsed >= MINIMUM_DISPLAY_SECONDS


func finish() -> void:
	active = false
	_runner.stop()
	set_process_input(false)
	hide()


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	progress = move_toward(progress, target_progress, delta / MINIMUM_DISPLAY_SECONDS)
	if can_finish() and not _display_finished:
		_display_finished = true
		display_finished.emit()


func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_screen = Control.new()
	_screen.name = "LoadingScreen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var background := ColorRect.new()
	background.name = "BlackBackground"
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(background)
	_content = Control.new()
	_content.name = "Content"
	_content.size = Vector2(320, 164)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_content)
	_runner = AnimatedSprite2D.new()
	_runner.name = "Runner"
	_runner.sprite_frames = RUNNER_FRAMES
	_runner.animation = &"run"
	_runner.centered = false
	_runner.offset = Vector2(-200, -420)
	_runner.position = Vector2(160, 92)
	_runner.scale = Vector2(0.19, 0.19)
	_runner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_content.add_child(_runner)
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.position = Vector2(0, 112)
	_loading_label.size = Vector2(320, 40)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_label.add_theme_font_size_override("font_size", 24)
	_loading_label.add_theme_color_override("font_color", Color(0.84, 0.87, 0.88))
	_content.add_child(_loading_label)
	_screen.resized.connect(_layout)
	_layout()


func _layout() -> void:
	var content_scale := minf(1.0, maxf(0.1, (_screen.size.x - 32.0) / 320.0))
	_content.scale = Vector2.ONE * content_scale
	_content.position = (_screen.size - _content.size * content_scale) * 0.5


func _update_language() -> void:
	var language := get_node_or_null("/root/Language")
	_loading_label.text = language.text("loading") if language != null else "Loading..."