extends Node

# InventoryManager — Глобальный менеджер инвентаря Даши (Detective Inventory System)
# Управляет физическими предметами, их количеством, описанием, подбором и использованием.

signal inventory_updated
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_used(item_id: String, success: bool)
signal toast_requested(message: String)

# Словарь предметов: item_id -> Dictionary
var _items: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Добавить предмет в инвентарь
func add_item(id: String, name: String, count: int = 1, icon: String = "📦", description: String = "", usable: bool = false) -> void:
	if count <= 0:
		return

	if _items.has(id):
		_items[id]["count"] += count
	else:
		_items[id] = {
			"id": id,
			"name": name,
			"count": count,
			"icon": icon,
			"description": description,
			"usable": usable
		}

	# Звук подбора предмета
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_interact"):
		sound_mgr.play_interact()

	# Уведомление
	var msg: String = "🎒 Подобрано: %s (x%d)  [ Нажмите I — Инвентарь ]" % [name, count]
	toast_requested.emit(msg)
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.emit(msg)

	item_added.emit(id, count)
	inventory_updated.emit()

## Удалить предмет или уменьшить количество
func remove_item(id: String, count: int = 1) -> bool:
	if not _items.has(id):
		return false

	var current_count: int = _items[id]["count"]
	if current_count < count:
		return false

	_items[id]["count"] -= count
	item_removed.emit(id, count)

	if _items[id]["count"] <= 0:
		_items.erase(id)

	inventory_updated.emit()
	return true

## Проверить наличие предмета
func has_item(id: String) -> bool:
	return _items.has(id) and _items[id]["count"] > 0

## Получить количество предмета
func get_item_count(id: String) -> int:
	if _items.has(id):
		return _items[id]["count"]
	return 0

## Получить данные предмета
func get_item(id: String) -> Dictionary:
	return _items.get(id, {})

## Получить список всех предметов
func get_all_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _items:
		result.append(_items[key])
	return result

## Использовать предмет по его идентификатору
func use_item(id: String) -> bool:
	if not has_item(id):
		return false

	var item_data: Dictionary = _items[id]
	if not item_data.get("usable", false):
		return false

	var success: bool = false

	# Логика конкретных предметов
	match id:
		"pills":
			success = _use_pills()
		_:
			# Для будущих предметов
			success = true
			remove_item(id, 1)

	if success:
		item_used.emit(id, true)
	else:
		item_used.emit(id, false)

	return success

func _use_pills() -> bool:
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")

	if sound_mgr and sound_mgr.has_method("play_pills_taken"):
		sound_mgr.play_pills_taken()

	if paranoia_mgr and paranoia_mgr.has_method("reduce_paranoia"):
		paranoia_mgr.reduce_paranoia(40.0)

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	var toast_msg: String = "💊 Принято седативное: пульс стабилизируется (-40% стресса)"
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.emit(toast_msg)
	toast_requested.emit(toast_msg)

	# Уменьшаем количество на 1
	remove_item("pills", 1)
	return true

## Сохранение инвентаря
func get_save_data() -> Dictionary:
	return _items.duplicate(true)

## Загрузка инвентаря
func load_save_data(data: Dictionary) -> void:
	_items.clear()
	for key in data:
		if data[key] is Dictionary:
			_items[key] = (data[key] as Dictionary).duplicate(true)
	inventory_updated.emit()

## Сброс инвентаря при новой игре
func reset_inventory() -> void:
	_items.clear()
	inventory_updated.emit()
