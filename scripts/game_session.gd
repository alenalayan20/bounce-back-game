extends Node
## Persistent menu/level music, saved volume controls and scene transitions.

signal settings_changed
signal pause_requested
signal scene_transition_started(destination: String)

const MENU_PATH := "res://scenes/main_menu.tscn"
const FIRST_LEVEL_PATH := "res://scenes/level_01.tscn"
const SETTINGS_PATH := "user://audio_settings.cfg"
const MUSIC_PATH := "res://audio/menu_music.ogg"
const LEVEL_MUSIC_PATH := "res://audio/level_music.ogg"
const LEVEL_PATHS := [
	"res://scenes/level_01.tscn",
	"res://scenes/level_02.tscn",
	"res://scenes/level_03.tscn",
	"res://scenes/level_04.tscn",
	"res://scenes/level_05.tscn",
]
const LOADING_SCREEN_PATH := "res://scenes/loading_overlay.tscn"
const MUSIC_BASE_DB: float = -2.0
# This recording is already quiet (about -31 dBFS RMS). With the default
# Master/Music sliders, -1 dB keeps it audible at roughly -39 dBFS RMS.
const LEVEL_MUSIC_BASE_DB: float = -1.0
const LEVEL_MUSIC_FADE_IN_SECONDS: float = 0.8
const FADE_SECONDS: float = 0.35

var game_volume: float = 0.8
var music_volume: float = 0.6
var music_player: AudioStreamPlayer
var level_music_player: AudioStreamPlayer
var loading_overlay
var _music_bus: int = -1
var _music_fade: Tween
var _level_music_fade: Tween
var _transition_pending: bool = false
var _transition_destination: String = ""
var _transition_scene: PackedScene
var _transition_committing: bool = false
var _load_requested: bool = false


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
	level_music_player = AudioStreamPlayer.new()
	level_music_player.name = "LevelMusic"
	level_music_player.bus = &"Music"
	level_music_player.volume_db = LEVEL_MUSIC_BASE_DB
	add_child(level_music_player)
	var level_source := load(LEVEL_MUSIC_PATH) as AudioStreamOggVorbis
	if level_source != null:
		var level_looping := level_source.duplicate() as AudioStreamOggVorbis
		level_looping.loop = true
		level_music_player.stream = level_looping
	get_tree().scene_changed.connect(_on_scene_changed)
	var loading_scene := load(LOADING_SCREEN_PATH) as PackedScene
	if loading_scene != null:
		loading_overlay = loading_scene.instantiate()
		add_child(loading_overlay)


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


func _play_level_music() -> void:
	if not is_instance_valid(level_music_player) or level_music_player.stream == null:
		return
	# Keeping the autoload's player running preserves its position across levels
	# and deaths. A scene change must never call play() on an already playing song.
	_cancel_level_music_fade()
	if not level_music_player.playing:
		level_music_player.volume_db = -60.0
		level_music_player.play()
	if not is_equal_approx(level_music_player.volume_db, LEVEL_MUSIC_BASE_DB):
		_level_music_fade = create_tween()
		_level_music_fade.tween_property(level_music_player, "volume_db", LEVEL_MUSIC_BASE_DB, LEVEL_MUSIC_FADE_IN_SECONDS)


func _stop_level_music(fade: bool = true) -> void:
	if not is_instance_valid(level_music_player):
		return
	_cancel_level_music_fade()
	if not level_music_player.playing:
		return
	if fade:
		_level_music_fade = create_tween()
		_level_music_fade.tween_property(level_music_player, "volume_db", -60.0, FADE_SECONDS)
		_level_music_fade.tween_callback(level_music_player.stop)
	else:
		level_music_player.stop()


func start_game() -> void:
	_request_scene(FIRST_LEVEL_PATH)


func return_to_menu() -> void:
	_request_scene(MENU_PATH)


func change_scene(destination: String) -> void:
	_request_scene(destination)


func _request_scene(destination: String) -> void:
	if _transition_pending:
		return
	_transition_pending = true
	_transition_destination = destination
	_transition_scene = null
	_transition_committing = false
	_load_requested = false
	get_tree().paused = false
	scene_transition_started.emit(destination)
	if destination != MENU_PATH:
		stop_menu_music()
	if not LEVEL_PATHS.has(destination):
		_stop_level_music()
	if is_instance_valid(loading_overlay):
		loading_overlay.begin()
	get_tree().paused = true
	_start_scene_load.call_deferred(destination)


func _start_scene_load(destination: String) -> void:
	if not _transition_pending or _transition_destination != destination:
		return
	var result := ResourceLoader.load_threaded_request(destination, "PackedScene", true)
	if result != OK:
		_fail_scene_transition(result)
	else:
		_load_requested = true


func _process(_delta: float) -> void:
	if not _transition_pending or not _load_requested or _transition_committing or _transition_destination.is_empty():
		return
	if _transition_scene == null:
		var resource_progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(_transition_destination, resource_progress)
		if not resource_progress.is_empty() and is_instance_valid(loading_overlay):
			loading_overlay.set_progress(float(resource_progress[0]))
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_transition_scene = ResourceLoader.load_threaded_get(_transition_destination) as PackedScene
				if _transition_scene == null:
					_fail_scene_transition(ERR_INVALID_DATA)
					return
				if is_instance_valid(loading_overlay):
					loading_overlay.set_progress(1.0)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_fail_scene_transition(ERR_CANT_OPEN)
				return
	if _transition_scene != null and (not is_instance_valid(loading_overlay) or loading_overlay.can_finish()):
		_transition_committing = true
		_change_scene.call_deferred()


func _change_scene() -> void:
	if not _transition_pending or _transition_scene == null:
		return
	get_tree().paused = false
	var result := get_tree().change_scene_to_packed(_transition_scene)
	if result != OK:
		_fail_scene_transition(result)


func _fail_scene_transition(error: int) -> void:
	var destination := _transition_destination
	_reset_scene_transition()
	push_error("Could not open scene: %s (error %d)" % [destination, error])
	_sync_music_with_scene()


func _reset_scene_transition() -> void:
	_transition_pending = false
	_transition_destination = ""
	_transition_scene = null
	_transition_committing = false
	_load_requested = false
	get_tree().paused = false
	if is_instance_valid(loading_overlay):
		loading_overlay.finish()


func _on_scene_changed() -> void:
	_reset_scene_transition()
	_sync_music_with_scene()


func _sync_music_with_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == MENU_PATH:
		_stop_level_music(false)
		play_menu_music()
	elif scene != null and LEVEL_PATHS.has(scene.scene_file_path):
		stop_menu_music(false)
		_play_level_music()
	else:
		stop_menu_music(false)
		_stop_level_music(false)


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


func _cancel_level_music_fade() -> void:
	if _level_music_fade != null and _level_music_fade.is_valid():
		_level_music_fade.kill()
	_level_music_fade = null


func _exit_tree() -> void:
	_cancel_music_fade()
	_cancel_level_music_fade()
	if is_instance_valid(music_player):
		music_player.stop()
	if is_instance_valid(level_music_player):
		level_music_player.stop()
