extends Node

# Менеджер системы сохранений (SaveManager)
# Поддерживает слоты сохранения, автосохранение, быстрое сохранение/загрузку

signal game_saved(slot_id: String, success: bool)
signal game_loaded(slot_id: String, success: bool)
signal save_deleted(slot_id: String)
signal toast_requested(message: String)

const SAVES_DIR: String = "user://saves/chapter_1/"
const SAVES_3D_DIR: String = "user://saves/chapter_1_3d/"
const CHAPTER_3D_SCENE: String = "res://scenes/chapter_1_3d/apartment.tscn"
const SCHEMA_3D: GDScript = preload("res://scripts/chapter_1_3d/save_schema.gd")
const CHAPTER_STATE: GDScript = preload("res://scripts/chapter_1/chapter_state.gd")
const CHAPTER_SCENE_PATH: String = "res://scenes/chapter_1/apartment.tscn"
const GAME_SCENE_PATH: String = "res://scenes/main.tscn"

var pending_save_data: Dictionary = {}
var last_used_slot: String = "slot_1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_saves_dir_exists()


func _ensure_saves_dir_exists() -> void:
	DirAccess.make_dir_recursive_absolute(_save_directory())

func _save_directory() -> String:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path in [CHAPTER_SCENE_PATH, GAME_SCENE_PATH]:
		return SAVES_DIR
	return SAVES_3D_DIR

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
		"version": 2,
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
			"door_opened": door_opened,
			"tutorial_stage": 4
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
	return _save_directory() + slot_id + ".json"

func save_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_id))

func get_save_info(slot_id: String) -> Dictionary:
	var path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(path) and _save_directory() == SAVES_3D_DIR and FileAccess.file_exists(SAVES_DIR + slot_id + ".json"):
		return {"exists": true, "compatible": false, "slot_id": slot_id, "title": _get_default_slot_title(slot_id), "timestamp": "2D", "location": "Предыдущая 2D-глава", "details": "Исходный файл сохранён без изменений"}
	if not FileAccess.file_exists(path) and FileAccess.file_exists("user://saves/" + slot_id + ".json"):
		return {"exists": true, "compatible": false, "slot_id": slot_id, "title": _get_default_slot_title(slot_id), "timestamp": "v1/v2", "location": "Технодемо · несовместимое сохранение", "details": "Исходный файл сохранён без изменений"}
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
		"compatible": SCHEMA_3D.valid(data) if _save_directory() == SAVES_3D_DIR else CHAPTER_STATE.valid(data),
		"slot_id": slot_id,
		"title": data.get("slot_title", _get_default_slot_title(slot_id)),
		"timestamp": data.get("timestamp", "Неизвестно"),
		"location": "Предыдущая планировка · начните новую игру" if int(data.get("version", 0)) == 3 and data.get("layout_revision", 0) != CHAPTER_STATE.LAYOUT_REVISION else data.get("location", "Конспиративная берлога"),
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
		if get_save_info(slot).get("compatible", false):
			return true
	return false

func get_latest_save_slot() -> String:
	var latest_slot: String = ""
	var latest_time: int = -1
	for slot in get_all_slots():
		var path: String = get_slot_path(slot)
		if FileAccess.file_exists(path) and get_save_info(slot).get("compatible", false):
			var mod_time: int = FileAccess.get_modified_time(path)
			if mod_time > latest_time:
				latest_time = mod_time
				latest_slot = slot
	return latest_slot

func save_game(slot_id: String, custom_title: String = "", location_override: String = "") -> bool:
	if slot_id not in get_all_slots(): return false
	_ensure_saves_dir_exists()
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		push_error("Невозможно сохранить: нет активной сцены")
		return false

	var current_scene: Node = tree.current_scene
	if current_scene.has_method("export_chapter_save"):
		return _save_chapter(current_scene, slot_id, custom_title, location_override)
	if current_scene.scene_file_path != GAME_SCENE_PATH:
		return false
	var dialogue: Node = current_scene.find_child("UI", true, false)
	if dialogue and dialogue.is_active:
		toast_requested.emit("Завершите разговор перед сохранением")
		game_saved.emit(slot_id, false)
		return false
	
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
		"version": 2,
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
			"door_opened": door_opened,
			"tutorial_stage": current_scene.get_node("Tutorial").stage
		},
		"world": {
			"pills_picked_up": current_scene.get_node("Pills").picked_up,
			"flashlight_on": current_scene.get_node("Player/Flashlight").is_on()
		},
		"paranoia": (get_node_or_null("/root/ParanoiaManager").get_paranoia() if get_node_or_null("/root/ParanoiaManager") else 22.0),
		"clues": (get_node_or_null("/root/ClueManager").get_save_data() if get_node_or_null("/root/ClueManager") else {}),
		"inventory": (get_node_or_null("/root/InventoryManager").get_save_data() if get_node_or_null("/root/InventoryManager") else {})
	}

	var file: FileAccess = FileAccess.open(get_slot_path(slot_id) + ".tmp", FileAccess.WRITE)
	if not file:
		push_error("Не удалось открыть файл для записи: " + get_slot_path(slot_id))
		game_saved.emit(slot_id, false)
		return false

	file.store_string(JSON.stringify(save_dict, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(get_slot_path(slot_id) + ".tmp", get_slot_path(slot_id)) != OK:
		game_saved.emit(slot_id, false)
		return false
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
	if slot_id not in get_all_slots(): return false
	var path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		toast_requested.emit("Слот пуст или относится к несовместимому технодемо")
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
	if not (SCHEMA_3D.valid(data) if _save_directory() == SAVES_3D_DIR else _valid_save(data)):
		toast_requested.emit("Сохранение повреждено или относится к несовместимой версии")
		game_loaded.emit(slot_id, false)
		return false
	if int(data.get("version", 0)) == 4:
		last_used_slot = slot_id
		get_tree().paused = false
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == CHAPTER_3D_SCENE:
			var loaded: bool = get_tree().current_scene.load_slot(slot_id)
			game_loaded.emit(slot_id, loaded)
			return loaded
		pending_save_data = data
		var changed: Error = get_tree().change_scene_to_file(CHAPTER_3D_SCENE)
		if changed != OK: pending_save_data = {}
		return changed == OK
	if int(data.get("version", 0)) == 3:
		pending_save_data = data
		last_used_slot = slot_id
		get_tree().paused = false
		if get_tree().current_scene and get_tree().current_scene.has_method("import_chapter_save"):
			apply_pending_save_if_any(get_tree().current_scene)
		else:
			get_tree().change_scene_to_file(CHAPTER_SCENE_PATH)
		game_loaded.emit(slot_id, true)
		return true
	# Historical scenes remain loadable only when explicitly running their regression harness.
	if not get_tree().current_scene or get_tree().current_scene.scene_file_path != GAME_SCENE_PATH:
		toast_requested.emit("Это сохранение технодемо v1/v2. Начните новую главу; исходный файл не изменён.")
		game_loaded.emit(slot_id, false)
		return false
	if int(data.get("version", 1)) == 1 and data.get("quest", {}).get("phone_answered", false) and not data.get("quest", {}).get("door_opened", false):
		data["quest"]["phone_answered"] = false
	pending_save_data = data
	last_used_slot = slot_id

	# Гарантированно снимаем паузу SceneTree перед загрузкой
	get_tree().paused = false

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_click"):
		sound_mgr.play_click()

	var current_scene: Node = get_tree().current_scene
	var is_already_game: bool = current_scene and current_scene.scene_file_path == GAME_SCENE_PATH

	if is_already_game:
		# Если мы уже находимся в игровой комнате, мгновенно восстанавливаем
		# состояние на месте без перезагрузки сцены и без потери фокуса ввода
		apply_pending_save_if_any(current_scene)
	else:
		# Если мы загружаемся из главного меню, переходим на сцену игры
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

	game_loaded.emit(slot_id, true)
	print("[SaveManager]: Сохранение '%s' успешно загружено" % slot_id)
	return true

func delete_save(slot_id: String) -> bool:
	if slot_id not in get_all_slots(): return false
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
	if int(pending_save_data.get("version", 0)) == 4:
		if scene_root.scene_file_path != CHAPTER_3D_SCENE: return false
		pending_save_data = {}
		var loaded: bool = scene_root.load_slot(last_used_slot)
		game_loaded.emit(last_used_slot, loaded)
		return loaded
	if int(pending_save_data.get("version", 0)) == 3:
		if not CHAPTER_STATE.valid(pending_save_data) or not scene_root.has_method("import_chapter_save"):
			pending_save_data = {}
			return false
		scene_root.import_chapter_save(pending_save_data)
		pending_save_data = {}
		return true

	var data: Dictionary = pending_save_data
	pending_save_data = {}

	# 1. Гарантированно снимаем паузу
	scene_root.get_tree().paused = false

	# 2. Восстанавливаем позицию и сбрасываем блокировку управления игрока
	var player_data: Dictionary = data.get("player", {})
	var player: Node = scene_root.find_child("Player", true, false)
	if player and player is CharacterBody2D:
		var px: float = float(player_data.get("pos_x", 480.0))
		var py: float = float(player_data.get("pos_y", 290.0))
		player.speed = float(player_data.get("speed", 240.0))
		var p_body: CharacterBody2D = player as CharacterBody2D
		p_body.global_position = Vector2(px, py)
		p_body.velocity = Vector2.ZERO
		if p_body.has_method("set_control_locked"):
			p_body.set_control_locked(false)

		# Мгновенно центрируем камеру на загруженном положении игрока
		var camera: Camera2D = p_body.get_node_or_null("Camera2D") as Camera2D
		if camera and camera.has_method("reset_smoothing"):
			camera.reset_smoothing()

	# 3. Восстанавливаем квест телефона
	var quest_data: Dictionary = data.get("quest", {})
	var phone_answered: bool = bool(quest_data.get("phone_answered", false))
	var quest_item: Node = scene_root.find_child("QuestItem", true, false)
	if quest_item:
		if quest_item.has_method("set_phone_state"):
			quest_item.set_phone_state(phone_answered)
		else:
			quest_item.is_phone_answered = phone_answered

	# 4. Восстанавливаем дверь
	var door_opened: bool = bool(quest_data.get("door_opened", false))
	var door: Node = scene_root.find_child("Door", true, false)
	if door:
		if door.has_method("set_state"):
			door.set_state(door_opened)
		elif door_opened and door.has_method("open"):
			door.open()

	# 5. Если в сцене был активен UI диалога, сбрасываем его
	var dialogue_ui: Node = scene_root.find_child("UI", true, false)
	if dialogue_ui:
		if dialogue_ui.has_method("cancel_dialogue"):
			dialogue_ui.cancel_dialogue()
		elif dialogue_ui.has_method("_close_dialogue"):
			dialogue_ui._close_dialogue()

	# 6. Восстанавливаем открытые улики
	var clues_data: Dictionary = data.get("clues", {})
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if clue_mgr and clue_mgr.has_method("load_save_data"):
		clue_mgr.load_save_data(clues_data)

	# 6.1. Восстанавливаем уровень пульса и паранойи
	var saved_paranoia: float = float(data.get("paranoia", 22.0))
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr and paranoia_mgr.has_method("set_paranoia"):
		paranoia_mgr.set_paranoia(saved_paranoia)

	# 6.2. Восстанавливаем предметы инвентаря
	var inventory_data: Dictionary = data.get("inventory", {})
	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("load_save_data"):
		inv_mgr.load_save_data(inventory_data)

	# Restore physical pickups independently of remaining inventory quantities.
	var world: Dictionary = data.get("world", {})
	var pills: Node = scene_root.get_node_or_null("Pills")
	if pills:
		pills.set_picked_up(bool(world.get("pills_picked_up", inventory_data.has("pills"))))
	var flashlight: Node = scene_root.get_node_or_null("Player/Flashlight")
	var tutorial: Node = scene_root.get_node_or_null("Tutorial")
	if tutorial:
		tutorial.apply_stage(int(quest_data.get("tutorial_stage", 4 if phone_answered else 0)))
	if flashlight:
		flashlight.toggle_flashlight(bool(world.get("flashlight_on", true)))
	for clue: Node in get_tree().get_nodes_in_group("interactive_clues"):
		clue.has_been_inspected = ClueManager.is_clue_discovered(clue.clue_id)

	# 7. Закрываем меню паузы, если оно отображается
	var inventory_ui: Node = scene_root.get_node_or_null("InventoryDialog")
	if inventory_ui and inventory_ui.is_open:
		inventory_ui.close_inventory()
	var pause_menu: Node = scene_root.find_child("PauseMenu", true, false)
	if pause_menu:
		if pause_menu.has_method("close_menu"):
			pause_menu.close_menu()
		else:
			var container: Control = pause_menu.get_node_or_null("PauseContainer") as Control
			if container:
				container.visible = false

	# 7. Показываем всплывающее уведомление о загрузке
	var toast_title: String = data.get("slot_title", _get_default_slot_title(last_used_slot))
	var toast_msg: String = "📂 Загружено: %s" % toast_title
	toast_requested.emit(toast_msg)

	print("[SaveManager]: Данные сохранения успешно применены к сцене.")
	return true

func _valid_save(data: Dictionary) -> bool:
	if data.get("version", 0) == 4: return SCHEMA_3D.valid(data)
	if data.get("version", 0) == 3:
		return CHAPTER_STATE.valid(data)
	if data.is_empty() or not (data.get("version", 1) is int or data.get("version", 1) is float):
		return false
	if not int(data.get("version", 1)) in [1, 2]:
		return false
	for section: String in ["player", "quest", "clues", "inventory", "world"]:
		if data.has(section) and not data[section] is Dictionary:
			return false
	for section: String in ["player", "quest", "world"]:
		for value: Variant in data.get(section, {}).values():
			if not (value is float or value is int or value is bool):
				return false
	var clues: Dictionary = data.get("clues", {})
	for key: String in clues:
		if not clues[key] is Dictionary:
			return false
		if key in ["clues", "deductions"]:
			for entry: Variant in clues[key].values():
				if not entry is Dictionary:
					return false
	for section: String in ["player", "quest", "world"]:
		for value: Variant in data.get(section, {}).values():
			if (value is float or value is int) and not is_finite(float(value)):
				return false
	for item: Variant in data.get("inventory", {}).values():
		if not item is Dictionary or not item.get("count", 0) is float and not item.get("count", 0) is int:
			return false
		for key: String in ["id", "name", "icon", "description"]:
			if item.has(key) and not item[key] is String:
				return false
		if item.has("usable") and not item["usable"] is bool:
			return false
		if not is_finite(float(item.get("count", 0))) or float(item.get("count", 0)) < 0:
			return false
	return data.get("paranoia", 22.0) is float or data.get("paranoia", 22.0) is int

func _save_chapter(scene: Node, slot: String, title: String, location: String) -> bool:
	if not scene.can_save_chapter():
		toast_requested.emit("Завершите действие и закройте окно перед сохранением")
		game_saved.emit(slot, false)
		return false
	var data: Dictionary = scene.export_chapter_save()
	data["slot_title"] = title if not title.is_empty() else _get_default_slot_title(slot)
	data["timestamp"] = Time.get_datetime_string_from_system().replace("T", " ")
	data["location"] = location if not location.is_empty() else "Глава 1 · Тёмная квартира"
	data["details"] = "Фаза: %s · стресс %d" % [data.chapter.phase, roundi(float(data.stress))]
	if not (SCHEMA_3D.valid(data) if int(data.get("version", 0)) == 4 else CHAPTER_STATE.valid(data)):
		game_saved.emit(slot, false)
		return false
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		game_saved.emit(slot, false)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(path + ".tmp", path)
	game_saved.emit(slot, result == OK)
	if result == OK:
		last_used_slot = slot
		toast_requested.emit("Сохранено · " + str(data.slot_title))
	else:
		toast_requested.emit("Не удалось записать сохранение")
	return result == OK
