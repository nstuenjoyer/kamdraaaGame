extends Node

# Менеджер настроек (SettingsManager)
# Управляет громкостью аудиошин, режимами экрана и сохраняет их в user://settings.json

signal settings_updated
signal keybinds_updated

const SETTINGS_FILE: String = "user://settings.json"

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_up", "name": "Движение вверх"},
	{"action": "move_down", "name": "Движение вниз"},
	{"action": "move_left", "name": "Движение влево"},
	{"action": "move_right", "name": "Движение вправо"},
	{"action": "interact", "name": "Взаимодействие / Диалог"},
	{"action": "quick_save", "name": "Быстрое сохранение"},
	{"action": "quick_load", "name": "Быстрая загрузка"},
	{"action": "toggle_clues", "name": "Материалы дела / Улики"},
	{"action": "toggle_mind_palace", "name": "Чертоги разума (Доска улик)"},
	{"action": "toggle_flashlight", "name": "Фонарик (Вкл / Выкл)"},
	{"action": "toggle_history", "name": "Журнал истории диалогов"},
	{"action": "toggle_fullscreen", "name": "Полный экран"}
]

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var crt_effect: bool = true

# Настройки текста и диалогов
var text_speed_mode: int = 2 # 0: Мгновенно, 1: Быстро, 2: Нормально, 3: Медленно
var auto_advance: bool = false
var auto_advance_delay: float = 2.0

var default_keybinds: Dictionary = {}
var custom_keybinds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_record_default_keybinds()
	load_settings()
	apply_settings()

func _record_default_keybinds() -> void:
	default_keybinds.clear()
	for item in REBINDABLE_ACTIONS:
		var act: String = item["action"]
		if InputMap.has_action(act):
			var events: Array[InputEvent] = InputMap.action_get_events(act)
			for ev in events:
				if ev is InputEventKey:
					var code: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
					if code != KEY_NONE:
						default_keybinds[act] = int(code)
						break

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
		master_volume = float(data.get("master_volume", 1.0))
		music_volume = float(data.get("music_volume", 1.0))
		sfx_volume = float(data.get("sfx_volume", 1.0))
		fullscreen = bool(data.get("fullscreen", false))
		vsync = bool(data.get("vsync", true))
		crt_effect = bool(data.get("crt_effect", true))
		text_speed_mode = int(data.get("text_speed_mode", 2))
		auto_advance = bool(data.get("auto_advance", false))
		auto_advance_delay = float(data.get("auto_advance_delay", 2.0))
		
		var saved_keys: Dictionary = data.get("keybinds", {})
		for act in saved_keys.keys():
			var code_int: int = int(saved_keys[act])
			if code_int > 0:
				custom_keybinds[act] = code_int
				_apply_action_key(act, code_int as Key)

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
		"crt_effect": crt_effect,
		"text_speed_mode": text_speed_mode,
		"auto_advance": auto_advance,
		"auto_advance_delay": auto_advance_delay,
		"keybinds": custom_keybinds
	}
	
	file.store_string(JSON.stringify(data, "\t"))

func get_typewriter_char_duration() -> float:
	match text_speed_mode:
		0: return 0.0 # Мгновенно
		1: return 0.012 # Быстро
		2: return 0.024 # Нормально
		3: return 0.045 # Медленно
		_: return 0.024

func get_speed_title(mode: int = -1) -> String:
	var m: int = text_speed_mode if mode == -1 else mode
	match m:
		0: return "Мгновенно"
		1: return "Быстро"
		2: return "Нормально"
		3: return "Медленно"
		_: return "Нормально"

func set_text_speed(mode: int, auto_save: bool = false) -> void:
	text_speed_mode = clampi(mode, 0, 3)
	settings_updated.emit()
	if auto_save:
		save_settings()

func set_auto_advance(enabled: bool, auto_save: bool = false) -> void:
	auto_advance = enabled
	settings_updated.emit()
	if auto_save:
		save_settings()

func set_auto_advance_delay(delay: float, auto_save: bool = false) -> void:
	auto_advance_delay = clampf(delay, 0.5, 10.0)
	settings_updated.emit()
	if auto_save:
		save_settings()

func _apply_action_key(action_name: String, key_code: Key) -> void:
	if not InputMap.has_action(action_name):
		return
	
	# Удаляем старые привязки клавиш клавиатуры для данного действия
	var old_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for ev in old_events:
		if ev is InputEventKey:
			InputMap.action_erase_event(action_name, ev)
	
	# Добавляем новую клавишу
	var new_ev: InputEventKey = InputEventKey.new()
	new_ev.physical_keycode = key_code
	new_ev.keycode = key_code
	InputMap.action_add_event(action_name, new_ev)

func rebind_action(action_name: String, new_keycode: Key, auto_save: bool = false) -> void:
	if not InputMap.has_action(action_name) or new_keycode == KEY_NONE:
		return
	
	_apply_action_key(action_name, new_keycode)
	custom_keybinds[action_name] = int(new_keycode)
	if auto_save:
		save_settings()
	keybinds_updated.emit()

func get_action_keycode(action_name: String) -> Key:
	if custom_keybinds.has(action_name):
		return custom_keybinds[action_name] as Key
	if default_keybinds.has(action_name):
		return default_keybinds[action_name] as Key
	if InputMap.has_action(action_name):
		var events: Array[InputEvent] = InputMap.action_get_events(action_name)
		for ev in events:
			if ev is InputEventKey:
				var k: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
				if k != KEY_NONE:
					return k
	return KEY_NONE

func get_action_key_name(action_name: String) -> String:
	var code: Key = get_action_keycode(action_name)
	if code == KEY_NONE:
		return "—"
	return OS.get_keycode_string(code)

func reset_keybinds_to_defaults(auto_save: bool = false) -> void:
	for item in REBINDABLE_ACTIONS:
		var act: String = item["action"]
		if default_keybinds.has(act):
			_apply_action_key(act, default_keybinds[act] as Key)
	custom_keybinds.clear()
	if auto_save:
		save_settings()
	keybinds_updated.emit()

func revert_settings() -> void:
	load_settings()
	apply_settings()

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

func set_master_volume(value: float, auto_save: bool = false) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	if auto_save:
		save_settings()

func set_music_volume(value: float, auto_save: bool = false) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	if auto_save:
		save_settings()

func set_sfx_volume(value: float, auto_save: bool = false) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	if auto_save:
		save_settings()

func set_fullscreen(enabled: bool, auto_save: bool = false) -> void:
	fullscreen = enabled
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if auto_save:
		save_settings()

func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") or (event is InputEventKey and event.keycode == KEY_F11 and event.pressed and not event.is_echo()):
		get_viewport().set_input_as_handled()
		toggle_fullscreen()

func set_vsync(enabled: bool, auto_save: bool = false) -> void:
	vsync = enabled
	var vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	if auto_save:
		save_settings()

func set_crt_effect(enabled: bool, auto_save: bool = false) -> void:
	crt_effect = enabled
	settings_updated.emit()
	if auto_save:
		save_settings()

