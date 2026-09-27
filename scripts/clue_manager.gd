extends Node

# Глобальный менеджер улик и подсказок (ClueManager)
# Отслеживает обнаружение улик, хранит материалы расследования и синхронизируется с SaveManager

signal clue_discovered(clue_id: String, clue_data: Dictionary)
signal clues_updated

# База данных всех сюжетных улик и подсказок игры
var _clues: Dictionary = {
	"receipt": {
		"id": "receipt",
		"title": "Смятый чек из бара",
		"icon": "🧾",
		"category": "Улика",
		"location": "Пол гостиной",
		"discovered": false,
		"discovered_at": "",
		"description": "Кассовый чек из бара «Неоновый туман», пробитый в 03:42 ночи. В чеке указаны 3 порции текилы, 2 абсента и штраф за разбитые бокалы. На обратной стороне чека торопливо выведено красной пастой: «Не доверяй тому, кто позвонит первым...»",
		"hint": "Кто-то пытался предупредить Дашу о готовящейся ловушке. Номер телефона заведения может содержать подсказку о районе города."
	},
	"mirror": {
		"id": "mirror",
		"title": "Помада на зеркале",
		"icon": "💄",
		"category": "Улика",
		"location": "Настенное зеркало",
		"discovered": false,
		"discovered_at": "",
		"description": "На стекле настенного зеркала жирной ярко-красной помадой начертано послание: «КОНСПИРАТИВНАЯ КВАРТИРА №4. ВЫХОД ЧЕРЕЗ ДВЕРЬ НА ЮГЕ». Внизу виден смазанный отпечаток губ. Даша пользуется исключительно тёмными оттенками помады.",
		"hint": "В квартире находился сообщник или куратор. Записка подтверждает, что южная бронированная дверь — единственный безопасный путь отхода."
	},
	"phone": {
		"id": "phone",
		"title": "Звонок от связного",
		"icon": "📞",
		"category": "Улика",
		"location": "Телефон на тумбочке",
		"discovered": false,
		"discovered_at": "",
		"description": "Неизвестный мужчина с прокуренным хриплым голосом назвал меня «Камарина», грубо отчитал за ночной разгром и приказал убираться из берлоги, пока не сел «хвост». После разговора он удалённо подал импульс на электронный замок.",
		"hint": "Собеседник ждёт Дашу внизу у подъезда. Но надпись на чеке категорически предостерегает доверять первому звонящему."
	},
	"bottle": {
		"id": "bottle",
		"title": "Разбитый абсент и след",
		"icon": "🍾",
		"category": "Улика",
		"location": "Ковёр возле центра",
		"discovered": false,
		"discovered_at": "",
		"description": "Осколки бутылки крепкого зелёного абсента «Fée Verte». В луже спиртного остался чёткий отпечаток подошвы тактического армейского берца 44-го размера. У Даши 37-й размер обуви.",
		"hint": "В квартиру заходил мужчина в армейской экипировке. Следы ведут от входной двери к телефонному аппарату."
	},
	"door": {
		"id": "door",
		"title": "Электронный замок",
		"icon": "🚪",
		"category": "Подсказка",
		"location": "Южная бронедверь",
		"discovered": false,
		"discovered_at": "",
		"description": "Тяжёлая сейфовая дверь с автономным микроконтроллером доступа. До телефонного звонка индикатор горел красным «Заперто». После звонка раздался щелчок сервопривода — дверь разблокирована.",
		"hint": "Путь в подъезд открыт. Снаружи могут поджидать как союзники, так и преследователи."
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Открыть улику по идентификатору
func discover_clue(clue_id: String) -> bool:
	if not _clues.has(clue_id):
		push_warning("ClueManager: неизвестный ID улики: " + clue_id)
		return false

	var clue: Dictionary = _clues[clue_id]
	if clue.get("discovered", false):
		return false

	clue["discovered"] = true
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	clue["discovered_at"] = "%02d:%02d:%02d" % [
		dt.get("hour", 0), dt.get("minute", 0), dt.get("second", 0)
	]

	# Звуковой отклик
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_clue_found"):
		sound_mgr.play_clue_found()

	# Уведомление через SaveManager/PauseMenu toast
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.emit("🔍 Новая улика: %s! [Tab]" % clue.get("title", ""))

	clue_discovered.emit(clue_id, clue)
	clues_updated.emit()
	return true

func is_clue_discovered(clue_id: String) -> bool:
	if _clues.has(clue_id):
		return bool(_clues[clue_id].get("discovered", false))
	return false

func get_clue(clue_id: String) -> Dictionary:
	return _clues.get(clue_id, {})

func get_all_clues() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	# Фиксированный порядок отображения для эстетики
	var order: Array[String] = ["receipt", "mirror", "bottle", "phone", "door"]
	for id: String in order:
		if _clues.has(id):
			list.append(_clues[id])
	return list

func get_discovered_count() -> int:
	var count: int = 0
	for k: String in _clues:
		if _clues[k].get("discovered", false):
			count += 1
	return count

func get_total_count() -> int:
	return _clues.size()

func get_save_data() -> Dictionary:
	var save_dict: Dictionary = {}
	for k: String in _clues:
		save_dict[k] = {
			"discovered": _clues[k].get("discovered", false),
			"discovered_at": _clues[k].get("discovered_at", "")
		}
	return save_dict

func load_save_data(data: Dictionary) -> void:
	for k: String in data:
		if _clues.has(k):
			var item: Dictionary = data[k]
			_clues[k]["discovered"] = bool(item.get("discovered", false))
			_clues[k]["discovered_at"] = str(item.get("discovered_at", ""))
	clues_updated.emit()

func reset_all_clues() -> void:
	for k: String in _clues:
		_clues[k]["discovered"] = false
		_clues[k]["discovered_at"] = ""
	clues_updated.emit()
