extends Node

# Глобальный менеджер улик, подсказок и чертогов разума (ClueManager)
# Отслеживает обнаружение улик, логические сопоставления («Чертоги разума»)
# и синхронизируется с SaveManager

signal clue_discovered(clue_id: String, clue_data: Dictionary)
signal clues_updated
signal deduction_unlocked(deduction_id: String, deduction_data: Dictionary)
signal deduction_failed(clue_a: String, clue_b: String, reason: String)

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

# База данных дедуктивных выводов («Чертоги разума»)
var _deductions: Dictionary = {
	"time_gap": {
		"id": "time_gap",
		"title": "Хронология провала (Окно: 33 минуты)",
		"icon": "⏱️",
		"clues": ["receipt", "mirror"],
		"unlocked": false,
		"unlocked_at": "",
		"insight": "Разница между временем в чеке (03:42) и надписью на зеркале (04:15) — ровно 33 минуты. За полчаса невозможно в одиночку доехать из центра, устроить погром и вывести послание чужой помадой. Я приехала сюда не одна... со мной был сообщник.",
		"narrative_effect": "Даша восстановила тайминг ночи. Снижение тревоги: -20%",
		"paranoia_relief": 20.0
	},
	"ambush_warning": {
		"id": "ambush_warning",
		"title": "Цена доверия (Предупреждение о связном)",
		"icon": "⚠️",
		"clues": ["receipt", "phone"],
		"unlocked": false,
		"unlocked_at": "",
		"insight": "На обратной стороне чека красной пастой выведено: «Не доверяй тому, кто позвонит первым...». Тот хриплый голос из телефонной трубки, который торопил меня выйти на улицу — именно он первым вышел на связь. Он не спасает меня, он выманивает меня из укрытия прямо под прицел преследователей!",
		"narrative_effect": "Даша раскрыла мотив звонившего. На выходе из подъезда ждёт засада. Снижение тревоги: -18%",
		"paranoia_relief": 18.0
	},
	"strangers_presence": {
		"id": "strangers_presence",
		"title": "Незваные гости (Два разных силуэта)",
		"icon": "👣",
		"clues": ["mirror", "bottle"],
		"unlocked": false,
		"unlocked_at": "",
		"insight": "В луже абсента след армейского берца 44-го размера, а на зеркале — жирный след чужой помады и женский почерк. В этой квартире ночью были как минимум двое посторонних: женщина-информатор и вооружённый оперативник в тактической экипировке.",
		"narrative_effect": "Раскрыт состав участников ночного инцидента. Снижение тревоги: -15%",
		"paranoia_relief": 15.0
	},
	"saboteur_route": {
		"id": "saboteur_route",
		"title": "Маршрут диверсанта (Следы у аппарата)",
		"icon": "🕵️",
		"clues": ["bottle", "phone"],
		"unlocked": false,
		"unlocked_at": "",
		"insight": "Отпечатки армейских берцев тянутся от разбитой бутылки прямо к тумбочке со стационарным телефоном. Мужчина в берцах стоял возле аппарата — он готовил линию связи или ждал, пока я очнусь, прежде чем передать сигнал кураторам.",
		"narrative_effect": "Даша поняла, откуда исходил звонок и что квартира была под наблюдением. Снижение тревоги: -15%",
		"paranoia_relief": 15.0
	},
	"remote_trap": {
		"id": "remote_trap",
		"title": "Электронный капкан (Удалённый контроль)",
		"icon": "🔓",
		"clues": ["phone", "door"],
		"unlocked": false,
		"unlocked_at": "",
		"insight": "Замок на южной бронедвери разблокировался строго синхронно с короткими гудками в трубке. Система безопасности конспиративной квартиры полностью завязана на внешнюю коммутацию. Связной держит руку на рубильнике и может запереть меня в любой миг.",
		"narrative_effect": "Подтверждён удалённый контроль квартиры. Свобода выхода — иллюзия. Снижение тревоги: -15%",
		"paranoia_relief": 15.0
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ========================================================
# Улики (Clues API)
# ========================================================

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
		save_mgr.toast_requested.emit("🔍 Новая улика: %s! [Tab / M]" % clue.get("title", ""))

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

# ========================================================
# Чертоги разума (Mind Palace & Deductions API)
# ========================================================

## Сопоставить две найденные улики в чертогах разума
func connect_clues(clue_a: String, clue_b: String) -> Dictionary:
	if clue_a == "" or clue_b == "":
		return {
			"success": false,
			"already_unlocked": false,
			"reason": "Для сопоставления необходимо выбрать две зацепки."
		}

	if clue_a == clue_b:
		return {
			"success": false,
			"already_unlocked": false,
			"reason": "Нельзя сопоставить улику саму с собой. Выберите две разные зацепки."
		}

	if not is_clue_discovered(clue_a) or not is_clue_discovered(clue_b):
		return {
			"success": false,
			"already_unlocked": false,
			"reason": "Одна из выбранных зацепок ещё не найдена или не изучена в комнате."
		}

	# Ищем дедуктивное совпадение
	var matched_deduction: Dictionary = {}
	for d_id: String in _deductions:
		var d: Dictionary = _deductions[d_id]
		var pair: Array = d.get("clues", [])
		if pair.has(clue_a) and pair.has(clue_b):
			matched_deduction = d
			break

	if matched_deduction.is_empty():
		var fail_reason: String = get_mismatch_reason(clue_a, clue_b)
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_deduction_fail"):
			sound_mgr.play_deduction_fail()
		deduction_failed.emit(clue_a, clue_b, fail_reason)
		return {
			"success": false,
			"already_unlocked": false,
			"reason": fail_reason
		}

	# Если вывод уже был получен ранее
	if matched_deduction.get("unlocked", false):
		return {
			"success": false,
			"already_unlocked": true,
			"deduction": matched_deduction,
			"reason": "Этот логический вывод уже сформирован и записан в чертогах разума."
		}

	# Успешный новый вывод (Эврика!)
	matched_deduction["unlocked"] = true
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	matched_deduction["unlocked_at"] = "%02d:%02d:%02d" % [
		dt.get("hour", 0), dt.get("minute", 0), dt.get("second", 0)
	]

	# Снижаем уровень тревоги/паранойи через ParanoiaManager
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr and paranoia_mgr.has_method("reduce_paranoia"):
		paranoia_mgr.reduce_paranoia(float(matched_deduction.get("paranoia_relief", 15.0)))

	# Звуковой триумф озарения
	var s_mgr: Node = get_node_or_null("/root/SoundManager")
	if s_mgr and s_mgr.has_method("play_deduction_success"):
		s_mgr.play_deduction_success()

	# Уведомление на экране
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.emit("🧩 Чертоги разума: «%s»! [M / Tab]" % matched_deduction.get("title", ""))

	deduction_unlocked.emit(matched_deduction.get("id", ""), matched_deduction)
	clues_updated.emit()

	return {
		"success": true,
		"already_unlocked": false,
		"deduction": matched_deduction,
		"reason": ""
	}

## Контекстные атмосферные мысли Даши при нестыковке зацепок
func get_mismatch_reason(clue_a: String, clue_b: String) -> String:
	var pair: Array[String] = [clue_a, clue_b]
	pair.sort()
	var key: String = pair[0] + "+" + pair[1]
	match key:
		"bottle+receipt":
			return "Чек из бара и разбитая бутылка абсента подтверждают ночную выпивку, но эти факты сами по себе не объясняют, кто устроил погром и кто оставил следы. Нужна другая зацепка."
		"door+mirror":
			return "Надпись на зеркале прямо указывает на эту дверь как выход. Но это и так ясно. Чтобы понять, кто оставил надпись и почему, сопоставьте помаду с другими следами."
		"door+receipt":
			return "Кассовый чек из бара «Неоновый туман» никак напрямую не связан с электрозамком бронированной двери."
		"bottle+door":
			return "Следы от армейских берцев направлены от двери внутрь помещения, а не к выходу. Здесь нет прямой разгадки без телефонного аппарата."
		_:
			return "Эти две зацепки пока не образуют логической связи в чертогах разума. Попробуйте поискать совпадения по времени, отпечаткам или действиям."

func is_deduction_unlocked(deduction_id: String) -> bool:
	if _deductions.has(deduction_id):
		return bool(_deductions[deduction_id].get("unlocked", false))
	return false

func get_deduction(deduction_id: String) -> Dictionary:
	return _deductions.get(deduction_id, {})

func get_all_deductions() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var order: Array[String] = ["time_gap", "ambush_warning", "strangers_presence", "saboteur_route", "remote_trap"]
	for d_id: String in order:
		if _deductions.has(d_id):
			list.append(_deductions[d_id])
	return list

func get_unlocked_deductions() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for d in get_all_deductions():
		if d.get("unlocked", false):
			list.append(d)
	return list

func get_unlocked_deductions_count() -> int:
	var count: int = 0
	for k: String in _deductions:
		if _deductions[k].get("unlocked", false):
			count += 1
	return count

func get_total_deductions_count() -> int:
	return _deductions.size()

# ========================================================
# Сериализация и сохранения (SaveManager sync)
# ========================================================

func get_save_data() -> Dictionary:
	var save_dict: Dictionary = {
		"clues": {},
		"deductions": {}
	}
	for k: String in _clues:
		save_dict["clues"][k] = {
			"discovered": _clues[k].get("discovered", false),
			"discovered_at": _clues[k].get("discovered_at", "")
		}
	for d_id: String in _deductions:
		save_dict["deductions"][d_id] = {
			"unlocked": _deductions[d_id].get("unlocked", false),
			"unlocked_at": _deductions[d_id].get("unlocked_at", "")
		}
	return save_dict

func load_save_data(data: Dictionary) -> void:
	if data.has("clues") or data.has("deductions"):
		var clues_dict: Dictionary = data.get("clues", {})
		for k: String in clues_dict:
			if _clues.has(k):
				var item: Dictionary = clues_dict[k]
				_clues[k]["discovered"] = bool(item.get("discovered", false))
				_clues[k]["discovered_at"] = str(item.get("discovered_at", ""))

		var ded_dict: Dictionary = data.get("deductions", {})
		for d_id: String in ded_dict:
			if _deductions.has(d_id):
				var item: Dictionary = ded_dict[d_id]
				_deductions[d_id]["unlocked"] = bool(item.get("unlocked", false))
				_deductions[d_id]["unlocked_at"] = str(item.get("unlocked_at", ""))
	else:
		# Обратная совместимость с плоской структурой сохранений
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
	for d_id: String in _deductions:
		_deductions[d_id]["unlocked"] = false
		_deductions[d_id]["unlocked_at"] = ""
	clues_updated.emit()
