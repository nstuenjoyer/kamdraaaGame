extends Node

# Менеджер системы сохранений (SaveManager)
# Поддерживает слоты сохранения, автосохранение, быстрое сохранение/загрузку

signal game_saved(slot_id: String, success: bool)
signal game_loaded(slot_id: String, success: bool)
signal save_deleted(slot_id: String)
signal toast_requested(message: String)

const SAVES_DIR: String = "user://saves/"
const GAME_SCENE_PATH: String = "res://scenes/main.tscn"

var pending_save_data: Dictionary = {}
var last_used_slot: String = "slot_1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_saves_dir_exists()
	_ensure_initial_saves_exist()

func _ensure_saves_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

func _ensure_initial_saves_exist() -> void:
	if not save_exists("slot_1"):
		create_sample_save_for_slot("slot_1")
	if not save_exists("autosave"):
		create_sample_save_for_slot("autosave")

func create_sample_saves() -> void:
	_ensure_saves_dir_exists()
	create_sample_save_for_slot("slot_1")
	create_sample_save_for_slot("autosave")

func create_sample_save_for_slot(slot_id: String) -> bool:
	_ensure_saves_dir_exists()
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var time_str: String = "%02d.%02d.%04d %02d:%02d:%02d" % [
		dt.get("day", 1), dt.get("month", 1), dt.get("year", 2026),
		dt.get("hour", 0), dt.get("minute", 0), dt.get("second", 0)
	]

	var title: String = ""
	var location: String = ""
	var details: String = ""
	var pos: Vector2 = Vector2(480, 290)
	var phone_answered: bool = false
	var door_opened: bool = false

	match slot_id:
		"slot_1":
			title = "Слот 1: Утро в берлоге — Пробуждение"
			location = "Квартира: Спальня Даши"
			details = "Дверь: Заперта | Телефон: Настойчиво звонит"
			pos = Vector2(480, 290)
			phone_answered = false
			door_opened = false
		"slot_2":
			title = "Слот 2: Разговор со связным"
			location = "Квартира: Телефонный столик"
			details = "Дверь: Заперта | Телефон: Разговор окончен"
			pos = Vector2(580, 310)
			phone_answered = true
			door_opened = false
		"slot_3":
			title = "Слот 3: В шаге от выхода"
			location = "Квартира: Коридор у двери"
			details = "Дверь: Открыта | Телефон: Разговор окончен"
			pos = Vector2(710, 420)
			phone_answered = true
			door_opened = true
		"autosave":
			title = "Автосохранение: Разблокированный выход"
			location = "Квартира: Выход в коридор"
			details = "Дверь: Открыта | Телефон: Разговор окончен"
			pos = Vector2(670, 360)
			phone_answered = true
			door_opened = true
		_:
			title = _get_default_slot_title(slot_id)
			location = "Квартира: Берлога"
			details = "Дверь: Заперта | Телефон: Звонит"

	var save_dict: Dictionary = {
		"version": 1,
		"slot_id": slot_id,
		"slot_title": title,
		"timestamp": time_str,
		"location": location,
		"details": details,
		"player": {
			"pos_x": pos.x,
			"pos_y": pos.y,
			"speed": 240.0
		},
		"quest": {
			"phone_answered": phone_answered,
			"door_opened": door_opened
		}
	}

	var path: String = get_slot_path(slot_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(save_dict, "\t"))
	print("[SaveManager]: Создано демо-сохранение для '%s'" % slot_id)
	return true

func get_slot_path(slot_id: String) -> String:
	return SAVES_DIR + slot_id + ".json"

func save_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_id))

func get_save_info(slot_id: String) -> Dictionary:
	var path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"slot_id": slot_id,
			"title": _get_default_slot_title(slot_id),
			"timestamp": "—",
			"location": "Пустая ячейка"
		}
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return { "exists": false, "slot_id": slot_id, "title": "Ошибка чтения" }
		
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		return { "exists": false, "slot_id": slot_id, "title": "Повреждённое сохранение" }
		
	var data: Dictionary = json.data
	return {
		"exists": true,
		"slot_id": slot_id,
		"title": data.get("slot_title", _get_default_slot_title(slot_id)),
		"timestamp": data.get("timestamp", "Неизвестно"),
		"location": data.get("location", "Конспиративная берлога"),
		"details": data.get("details", "")
	}

func _get_default_slot_title(slot_id: String) -> String:
	match slot_id:
		"slot_1": return "Слот 1"
		"slot_2": return "Слот 2"
		"slot_3": return "Слот 3"
		"autosave": return "Автосохранение"
		_: return slot_id.capitalize()

func get_all_slots() -> Array[String]:
	return ["slot_1", "slot_2", "slot_3", "autosave"]

func has_any_save() -> bool:
	for slot in get_all_slots():
		if save_exists(slot):
			return true
	return false

func get_latest_save_slot() -> String:
	var latest_slot: String = ""
	var latest_time: int = -1
	for slot in get_all_slots():
		var path: String = get_slot_path(slot)
		if FileAccess.file_exists(path):
			var mod_time: int = FileAccess.get_modified_time(path)
			if mod_time > latest_time:
				latest_time = mod_time
				latest_slot = slot
	return latest_slot

func save_game(slot_id: String, custom_title: String = "", location_override: String = "") -> bool:
	_ensure_saves_dir_exists()
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		push_error("Невозможно сохранить: нет активной сцены")
		return false

	var current_scene: Node = tree.current_scene
	
	# Извлекаем состояние игрока
	var player: Node = current_scene.find_child("Player", true, false)
	var player_pos: Vector2 = Vector2(480, 290)
	var player_speed: float = 240.0
	if player and player is Node2D:
		player_pos = (player as Node2D).global_position
		if "speed" in player:
			player_speed = player.speed

	# Извлекаем состояние квестового телефона
	var quest_item: Node = current_scene.find_child("QuestItem", true, false)
	var phone_answered: bool = false
	if quest_item and "is_phone_answered" in quest_item:
		phone_answered = bool(quest_item.is_phone_answered)

	# Извлекаем состояние двери
	var door: Node = current_scene.find_child("Door", true, false)
	var door_opened: bool = false
	if door and "is_opened" in door:
		door_opened = bool(door.is_opened)

	# Форматируем текущие дату и время
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp_str: String = "%02d.%02d.%04d %02d:%02d:%02d" % [
		dt.get("day", 1), dt.get("month", 1), dt.get("year", 2026),
		dt.get("hour", 0), dt.get("minute", 0), dt.get("second", 0)
	]

	var title: String = custom_title if not custom_title.is_empty() else _get_default_slot_title(slot_id)
	var location: String = location_override if not location_override.is_empty() else "Квартира: Берлога"
	
	var details: String = "Дверь: %s | Телефон: %s" % [
		"Открыта" if door_opened else "Заперта",
		"Отвечен" if phone_answered else "Звонит"
	]

	var save_dict: Dictionary = {
		"version": 1,
		"slot_id": slot_id,
		"slot_title": title,
		"timestamp": timestamp_str,
		"location": location,
		"details": details,
		"player": {
			"pos_x": player_pos.x,
			"pos_y": player_pos.y,
			"speed": player_speed
		},
		"quest": {
			"phone_answered": phone_answered,
			"door_opened": door_opened
		}
	}

	var file: FileAccess = FileAccess.open(get_slot_path(slot_id), FileAccess.WRITE)
	if not file:
		push_error("Не удалось открыть файл для записи: " + get_slot_path(slot_id))
		game_saved.emit(slot_id, false)
		return false

	file.store_string(JSON.stringify(save_dict, "\t"))
	last_used_slot = slot_id

	# Звуковой отклик и уведомление
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_save"):
		sound_mgr.play_save()

	var toast_msg: String = "💾 Игра сохранена в %s" % title
	toast_requested.emit(toast_msg)
	game_saved.emit(slot_id, true)
	print("[SaveManager]: Игра успешно сохранена в '%s'" % slot_id)
	return true

func load_game(slot_id: String) -> bool:
	var path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		push_error("Файл сохранения не найден: " + path)
		game_loaded.emit(slot_id, false)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		game_loaded.emit(slot_id, false)
		return false

	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		push_error("Ошибка парсинга файла сохранения: " + path)
		game_loaded.emit(slot_id, false)
		return false

	var data: Dictionary = json.data
	pending_save_data = data
	last_used_slot = slot_id

	var current_scene: Node = get_tree().current_scene
	var is_already_game: bool = current_scene and current_scene.scene_file_path == GAME_SCENE_PATH

	if is_already_game:
		apply_pending_save_if_any(current_scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_click"):
		sound_mgr.play_click()

	var toast_msg: String = "📂 Загружено: %s" % data.get("slot_title", slot_id)
	toast_requested.emit(toast_msg)
	game_loaded.emit(slot_id, true)
	print("[SaveManager]: Сохранение '%s' загружено" % slot_id)
	return true

func delete_save(slot_id: String) -> bool:
	var path: String = get_slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		save_deleted.emit(slot_id)
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_cancel"):
			sound_mgr.play_cancel()
		toast_requested.emit("🗑 Сохранение '%s' удалено" % _get_default_slot_title(slot_id))
		return true
	return false

func auto_save(location_description: String = "") -> void:
	save_game("autosave", "Автосохранение", location_description)

func apply_pending_save_if_any(scene_root: Node) -> bool:
	if pending_save_data.is_empty():
		return false

	var data: Dictionary = pending_save_data
	pending_save_data = {}

	# Восстанавливаем позицию игрока
	var player_data: Dictionary = data.get("player", {})
	var player: Node = scene_root.find_child("Player", true, false)
	if player and player is CharacterBody2D:
		var px: float = float(player_data.get("pos_x", 480.0))
		var py: float = float(player_data.get("pos_y", 290.0))
		(player as CharacterBody2D).global_position = Vector2(px, py)

	# Восстанавливаем квест телефона
	var quest_data: Dictionary = data.get("quest", {})
	var phone_answered: bool = bool(quest_data.get("phone_answered", false))
	var quest_item: Node = scene_root.find_child("QuestItem", true, false)
	if quest_item:
		if quest_item.has_method("set_phone_state"):
			quest_item.set_phone_state(phone_answered)
		else:
			quest_item.is_phone_answered = phone_answered

	# Восстанавливаем дверь
	var door_opened: bool = bool(quest_data.get("door_opened", false))
	var door: Node = scene_root.find_child("Door", true, false)
	if door:
		if door.has_method("set_state"):
			door.set_state(door_opened)
		elif door_opened and door.has_method("open"):
			door.open()

	print("[SaveManager]: Данные сохранения успешно применены к сцене.")
	return true
