extends Node
## Shared menu music, saved volume controls and scene transitions.

signal settings_changed
signal pause_requested
signal scene_transition_started(destination: String)

const MENU_PATH := "res://scenes/main_menu.tscn"
const FIRST_LEVEL_PATH := "res://scenes/level_01.tscn"
const SETTINGS_PATH := "user://audio_settings.cfg"
const MUSIC_PATH := "res://audio/menu_music.ogg"
const MUSIC_BASE_DB: float = -2.0
const FADE_SECONDS: float = 0.35

var game_volume: float = 0.8
var music_volume: float = 0.6
var music_player: AudioStreamPlayer
var _music_bus: int = -1
var _music_fade: Tween
var _transition_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_music_bus()
	_apply_volumes()
	music_player = AudioStreamPlayer.new()
	music_player.name = "MenuMusic"
	music_player.bus = &"Music"
	music_player.volume_db = MUSIC_BASE_DB
	add_child(music_player)
	var source := load(MUSIC_PATH) as AudioStreamOggVorbis
	if source != null:
		var looping := source.duplicate() as AudioStreamOggVorbis
		looping.loop = true
		music_player.stream = looping
	get_tree().scene_changed.connect(_on_scene_changed)


func set_game_volume(value: float) -> void:
	game_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()
	settings_changed.emit()


func play_menu_music(fade: bool = true) -> void:
	if not is_instance_valid(music_player) or music_player.stream == null:
		return
	_cancel_music_fade()
	if not music_player.playing:
		music_player.volume_db = -60.0 if fade else MUSIC_BASE_DB
		music_player.play()
	if fade:
		_music_fade = create_tween()
		_music_fade.tween_property(music_player, "volume_db", MUSIC_BASE_DB, FADE_SECONDS)
	else:
		music_player.volume_db = MUSIC_BASE_DB


func stop_menu_music(fade: bool = true) -> void:
	if not is_instance_valid(music_player):
		return
	_cancel_music_fade()
	if not music_player.playing:
		return
	if fade:
		_music_fade = create_tween()
		_music_fade.tween_property(music_player, "volume_db", -60.0, FADE_SECONDS)
		_music_fade.tween_callback(music_player.stop)
	else:
		music_player.stop()


func start_game() -> void:
	_request_scene(FIRST_LEVEL_PATH)


func return_to_menu() -> void:
	_request_scene(MENU_PATH)


func _request_scene(destination: String) -> void:
	if _transition_pending:
		return
	_transition_pending = true
	get_tree().paused = false
	scene_transition_started.emit(destination)
	if destination != MENU_PATH:
		stop_menu_music()
	_change_scene.call_deferred(destination)


func _change_scene(destination: String) -> void:
	var result := get_tree().change_scene_to_file(destination)
	if result != OK:
		_transition_pending = false
		push_error("Could not open scene: %s (error %d)" % [destination, result])
		_sync_music_with_scene()


func _on_scene_changed() -> void:
	_transition_pending = false
	_sync_music_with_scene()


func _sync_music_with_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == MENU_PATH:
		play_menu_music()
	else:
		stop_menu_music()


func _ensure_music_bus() -> void:
	_music_bus = AudioServer.get_bus_index(&"Music")
	if _music_bus < 0:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, &"Music")
	AudioServer.set_bus_send(_music_bus, &"Master")


func _apply_volumes() -> void:
	AudioServer.set_bus_mute(0, game_volume <= 0.0001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(game_volume, 0.0001)))
	if _music_bus >= 0:
		AudioServer.set_bus_mute(_music_bus, music_volume <= 0.0001)
		AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(music_volume, 0.0001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_game = config.get_value("audio", "game_volume", game_volume)
	var saved_music = config.get_value("audio", "music_volume", music_volume)
	if typeof(saved_game) == TYPE_FLOAT or typeof(saved_game) == TYPE_INT:
		game_volume = clampf(float(saved_game), 0.0, 1.0)
	if typeof(saved_music) == TYPE_FLOAT or typeof(saved_music) == TYPE_INT:
		music_volume = clampf(float(saved_music), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "game_volume", game_volume)
	config.set_value("audio", "music_volume", music_volume)
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save volume settings (error %d)" % result)


func _cancel_music_fade() -> void:
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	_music_fade = null


func _exit_tree() -> void:
	_cancel_music_fade()
	if is_instance_valid(music_player):
		music_player.stop()
