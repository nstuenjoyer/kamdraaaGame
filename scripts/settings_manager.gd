extends Node

# Менеджер настроек (SettingsManager)
# Управляет громкостью аудиошин, режимами экрана и сохраняет их в user://settings.json

signal settings_updated

const SETTINGS_FILE: String = "user://settings.json"

var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.8
var fullscreen: bool = false
var vsync: bool = true
var crt_effect: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		save_settings()
		return
		
	var file: FileAccess = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		return
		
	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		master_volume = float(data.get("master_volume", 0.8))
		music_volume = float(data.get("music_volume", 0.8))
		sfx_volume = float(data.get("sfx_volume", 0.8))
		fullscreen = bool(data.get("fullscreen", false))
		vsync = bool(data.get("vsync", true))
		crt_effect = bool(data.get("crt_effect", true))

func save_settings() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if not file:
		push_error("Не удалось открыть файл для записи настроек: " + SETTINGS_FILE)
		return
		
	var data: Dictionary = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"vsync": vsync,
		"crt_effect": crt_effect
	}
	
	file.store_string(JSON.stringify(data, "\t"))

func apply_settings() -> void:
	# Применение громкости звуковых шин
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	
	# Полноэкранный режим
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	# Вертикальная синхронизация (V-Sync)
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	
	settings_updated.emit()

func _apply_bus_volume(bus_name: String, volume_linear: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if volume_linear <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume_linear))

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	save_settings()

func set_crt_effect(enabled: bool) -> void:
	crt_effect = enabled
	settings_updated.emit()
	save_settings()
