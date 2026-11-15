extends Control
## Functional controls over the supplied settings artwork.

signal closed

const SETTINGS_ART := preload("res://interface/settings_interface.png")
const PANEL_TINT := Color(17.0 / 255.0, 20.0 / 255.0, 25.0 / 255.0, 1.0)

var game_slider: HSlider
var music_slider: HSlider
var game_value: Label
var music_value: Label
var close_button: Button
var done_button: Button

var _updating: bool = false
var _fallback_game_volume: float = 0.8
var _fallback_music_volume: float = 0.6
var _previous_focus: WeakRef


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var session := _session()
	if session != null and session.has_signal("settings_changed"):
		session.settings_changed.connect(_sync_from_session)
	_sync_from_session()
	hide()


func open() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	_sync_from_session()
	show()
	game_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	if _previous_focus != null:
		var previous = _previous_focus.get_ref()
		if is_instance_valid(previous) and previous is Control and previous.is_visible_in_tree():
			previous.grab_focus()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _sync_from_session() -> void:
	if game_slider == null:
		return
	var session := _session()
	var game_volume: float = _fallback_game_volume
	var music_volume: float = _fallback_music_volume
	if session != null:
		game_volume = float(session.get("game_volume"))
		music_volume = float(session.get("music_volume"))
	_updating = true
	game_slider.value = game_volume * 100.0
	music_slider.value = music_volume * 100.0
	game_value.text = "%d%%" % roundi(game_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	_updating = false


func _on_game_volume_changed(value: float) -> void:
	game_value.text = "%d%%" % roundi(value)
	if _updating:
		return
	_fallback_game_volume = value / 100.0
	var session := _session()
	if session != null:
		session.set_game_volume(_fallback_game_volume)


func _on_music_volume_changed(value: float) -> void:
	music_value.text = "%d%%" % roundi(value)
	if _updating:
		return
	_fallback_music_volume = value / 100.0
	var session := _session()
	if session != null:
		session.set_music_volume(_fallback_music_volume)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content := Control.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(900, 420)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)

	_add_art(content, "Header", Rect2(110, 76, 545, 138), Vector2(14, 0), Vector2(327, 83))
	_add_art(content, "AudioPanel", Rect2(108, 389, 1453, 309), Vector2(14, 110), Vector2(872, 185.4))

	close_button = Button.new()
	close_button.name = "Close"
	close_button.position = Vector2(803, 0)
	close_button.size = Vector2(83, 83)
	for state in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var close_art := Sprite2D.new()
	close_art.texture = _atlas(Rect2(1416, 76, 143, 143))
	close_art.centered = false
	close_art.scale = Vector2(83.0 / 143.0, 83.0 / 143.0)
	close_button.add_child(close_art)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.tooltip_text = "Закрыть настройки"
	content.add_child(close_button)
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(_highlight_close.bind(true))
	close_button.mouse_exited.connect(_highlight_close.bind(false))
	close_button.focus_entered.connect(_highlight_close.bind(true))
	close_button.focus_exited.connect(_highlight_close.bind(false))

	# The art contains example sliders and values. These patches remove only
	# their drawn pixels; the controls below are the real interactive values.
	_add_patch(content, "GameTrackPatch", Rect2(371.6, 176.6, 398.4, 37.8))
	_add_patch(content, "MusicTrackPatch", Rect2(371.6, 224.6, 398.4, 39.6))
	_add_patch(content, "GameValuePatch", Rect2(785.6, 176.6, 91.2, 37.8))
	_add_patch(content, "MusicValuePatch", Rect2(785.6, 224.6, 91.2, 39.6))

	game_slider = _make_slider("GameSlider", content, Vector2(378.2, 176.6), Vector2(380.4, 37.8))
	music_slider = _make_slider("MusicSlider", content, Vector2(378.2, 224.6), Vector2(380.4, 39.6))
	game_value = _make_percentage("GameValue", content, Vector2(785.6, 176.6), Vector2(91.2, 37.8))
	music_value = _make_percentage("MusicValue", content, Vector2(785.6, 224.6), Vector2(91.2, 39.6))
	game_slider.value_changed.connect(_on_game_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)

	var helper := Label.new()
	helper.name = "SaveHint"
	helper.position = Vector2(14, 306)
	helper.size = Vector2(872, 24)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	helper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helper.text = "Настройки сохраняются автоматически"
	helper.add_theme_font_size_override("font_size", 15)
	helper.add_theme_color_override("font_color", Color(0.58, 0.65, 0.72))
	content.add_child(helper)

	done_button = Button.new()
	done_button.name = "Done"
	done_button.text = "Готово"
	done_button.position = Vector2(350, 346)
	done_button.size = Vector2(200, 48)
	done_button.add_theme_font_size_override("font_size", 20)
	done_button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.09, 0.14), Color(0.12, 0.4, 0.61)))
	done_button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.17, 0.25), Color(0.15, 0.65, 0.9)))
	done_button.add_theme_stylebox_override("pressed", _button_style(Color(0.025, 0.08, 0.13), Color(0.15, 0.65, 0.9)))
	done_button.add_theme_stylebox_override("focus", _focus_style())
	content.add_child(done_button)
	done_button.pressed.connect(close)

	game_slider.focus_next = music_slider.get_path()
	game_slider.focus_previous = close_button.get_path()
	music_slider.focus_next = done_button.get_path()
	music_slider.focus_previous = game_slider.get_path()
	done_button.focus_next = close_button.get_path()
	done_button.focus_previous = music_slider.get_path()
	close_button.focus_next = game_slider.get_path()
	close_button.focus_previous = done_button.get_path()


func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SETTINGS_ART
	texture.region = region
	return texture


func _add_art(parent: Control, node_name: String, region: Rect2, at: Vector2, dimensions: Vector2) -> void:
	var art := Sprite2D.new()
	art.name = node_name
	art.texture = _atlas(region)
	art.position = at
	art.centered = false
	art.scale = dimensions / region.size
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(art)


func _add_patch(parent: Control, node_name: String, rectangle: Rect2) -> void:
	var patch := ColorRect.new()
	patch.name = node_name
	patch.position = rectangle.position
	patch.size = rectangle.size
	patch.color = PANEL_TINT
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(patch)


func _make_slider(node_name: String, parent: Control, at: Vector2, dimensions: Vector2) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.position = at
	slider.size = dimensions
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.focus_mode = Control.FOCUS_ALL
	slider.add_theme_icon_override("grabber", _knob_texture(Color(0.94, 0.97, 1)))
	slider.add_theme_icon_override("grabber_highlight", _knob_texture(Color.WHITE))
	slider.add_theme_icon_override("grabber_disabled", _knob_texture(Color(0.5, 0.56, 0.62)))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.19, 0.21, 0.25)
	track.corner_radius_top_left = 6
	track.corner_radius_top_right = 6
	track.corner_radius_bottom_left = 6
	track.corner_radius_bottom_right = 6
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.0, 0.6, 0.96)
	slider.add_theme_stylebox_override("grabber_area", fill)
	var fill_active := fill.duplicate() as StyleBoxFlat
	fill_active.bg_color = Color(0.1, 0.73, 1)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_active)
	slider.add_theme_stylebox_override("focus", _focus_style())
	parent.add_child(slider)
	return slider


func _make_percentage(node_name: String, parent: Control, at: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99))
	parent.add_child(label)
	return label


func _knob_texture(tint: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 0.93, 1.0])
	gradient.colors = PackedColorArray([tint, tint, Color(tint, 0.6), Color(tint, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 28
	texture.height = 28
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _focus_style() -> StyleBoxFlat:
	var focus := _button_style(Color(0, 0, 0, 0), Color(0.15, 0.7, 1, 0.8))
	return focus


func _highlight_close(highlighted: bool) -> void:
	close_button.modulate = Color(1.15, 1.15, 1.15) if highlighted or close_button.has_focus() else Color.WHITE
