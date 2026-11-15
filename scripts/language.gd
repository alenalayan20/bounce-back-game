extends Node
## The player's language choice is independent of the OS and audio settings.

signal language_changed

const SETTINGS_PATH := "user://language.cfg"
const STRINGS := {
	"en": {
		"loading": "Loading...",
		"play": "Play",
		"exit": "Exit",
		"settings": "Settings",
		"close_settings": "Close settings",
		"audio": "Audio",
		"game_volume": "Game volume",
		"music": "Music",
		"language": "Language",
		"saved_automatically": "Settings are saved automatically",
		"done": "Done",
		"paused": "PAUSED",
		"resume": "Resume",
		"main_menu": "Main menu",
		"level_title": "LEVEL %02d",
		"deaths": "Deaths: %d",
		"retry_status": "Try again",
		"next_level": "Level %d  ↵",
		"replay": "Play again  ↵",
		"level_complete": "Level %d complete!\nDeaths: %d",
		"level_complete_short": "Level %d complete!",
		"platform_controls": "A / D or ← / → — move    W / ↑ / Space — jump    R — restart    Esc — pause",
		"maze_controls": "W A S D or arrows — move    R — restart    Esc — pause",
		"game_complete": "You escaped!\nGame complete!",
		"back_to_menu": "Back to menu  ↵",
	},
	"ru": {
		"loading": "Загрузка...",
		"play": "Играть",
		"exit": "Выход",
		"settings": "Настройки",
		"close_settings": "Закрыть настройки",
		"audio": "Звук",
		"game_volume": "Громкость игры",
		"music": "Музыка",
		"language": "Язык",
		"saved_automatically": "Настройки сохраняются автоматически",
		"done": "Готово",
		"paused": "ПАУЗА",
		"resume": "Продолжить",
		"main_menu": "Главное меню",
		"level_title": "УРОВЕНЬ %02d",
		"deaths": "Смерти: %d",
		"retry_status": "Ещё попытка",
		"next_level": "Уровень %d  ↵",
		"replay": "Ещё раз  ↵",
		"level_complete": "Уровень %d пройден!\nСмертей: %d",
		"level_complete_short": "Уровень %d пройден!",
		"platform_controls": "A / D или ← / → — движение    W / ↑ / Пробел — прыжок    R — заново    Esc — пауза",
		"maze_controls": "W A S D или стрелки — движение    R — заново    Esc — пауза",
		"game_complete": "Ты выбрался!\nИгра пройдена!",
		"back_to_menu": "Назад в меню  ↵",
	},
}

var current_code: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved = config.get_value("language", "code", "en")
		if saved is String and STRINGS.has(saved):
			current_code = saved


func text(key: String) -> String:
	return str(STRINGS[current_code].get(key, STRINGS["en"].get(key, key)))


func set_language(code: String) -> void:
	if not STRINGS.has(code) or code == current_code:
		return
	current_code = code
	var config := ConfigFile.new()
	config.set_value("language", "code", current_code)
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save language settings (error %d)" % result)
	language_changed.emit()
