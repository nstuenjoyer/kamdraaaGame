extends RefCounted

var host: Node2D
var pin: Array[int] = [0, 0, 0, 0]
var latch: Array[int] = [0, 0, 0]
var breakers: Array[bool] = [false, false, false]
var attempts: int = 0
var pin_error: String = ""
var latch_error: String = ""
var power_error: String = ""
var active_digit: int = 0

func setup(controller: Node2D) -> void:
	host = controller

func goal() -> String:
	var s: ApartmentState = host.state
	if not s.has("dose"): return ""
	if s.phase in ["encounter", "resolved", "complete"]: return ""
	if s.has("coat"): return "Вернитесь к входной двери"
	if not s.has("exit_checked"): return "Проверьте входную дверь"
	if not s.has("jacket_checked"): return "Осмотрите свою куртку"
	if not s.has("study_key"): return "Найдите ключ от кабинета"
	if not s.has("study_unlocked"): return "Откройте кабинет"
	if not s.has("cabinet_checked"): return "Осмотрите картотеку в кабинете"
	if not s.has("cabinet_unlocked"): return "Узнайте время отключения света"
	if not s.has("sofa_searched"): return "Проверьте подушки дивана"
	if s.diary_choice.is_empty(): return "Прочитайте дневник и решите"
	if not s.has("screwdriver"): return "Возьмите отвёртку в постирочной"
	if not s.has("latch_released"): return "Освободите дверной засов"
	return "Откройте входную дверь"

func details() -> String:
	var s: ApartmentState = host.state
	if not s.has("exit_checked"): return "Квартира погружена в темноту. Сначала проверьте, можно ли выйти: дверь в дальнем конце прихожей. Свет можно починить или пользоваться найденным фонариком."
	if not s.has("jacket_checked"): return "Входного ключа нет. Даша обычно оставляет его в кармане своей куртки в спальне. Верхний засов двери тоже заклинило."
	if not s.has("study_key"): return "В кармане остался листок: запасной ключ от кабинета висит в кухонной ключнице. Кабинет находится за галереей, рядом с постирочной."
	if not s.has("study_unlocked"): return "Ключ от кабинета найден. Дверь в конце гостиной, за поперечной галереей. После отпирания откроется и боковой проход в задний коридор."
	if not s.has("cabinet_checked"): return "На письменном столе лежит записка. Картотека с запасными ключами стоит у дальней стены кабинета."
	if not s.has("cabinet_unlocked"): return "Код картотеки — время вчерашнего отключения, четыре цифры. На часах в гостиной 21:40, но они заводятся отдельно. Сравните их с кухонной запиской; журнал отключений в постирочной поможет проверить вывод. Найденные записи доступны на второй вкладке."
	if not s.has("sofa_searched"): return "В картотеке нашлись входной ключ и приписка: дневник убран под диванную подушку. Гостиная изменилась со вчерашнего вечера — стоит прочитать свои записи."
	if s.diary_choice.is_empty(): return "Дневник описывает слежку. Дочитайте его и выберите, довериться записям или проверить всё самостоятельно. Баллончик в шкафу можно найти в обеих ветках."
	if not s.has("screwdriver"): return "Входной ключ есть, но перекосило верхний засов. Нужна отвёртка из рабочего ящика в постирочной. Это не обязывает ремонтировать электричество."
	if not s.has("latch_released"): return "Откройте крышку верхнего засова и совместите три ползуна с рисками на корпусе. Ремонт света, телефон и средство защиты остаются необязательными."
	return "Выход подготовлен. Перед уходом можно вернуться за средством защиты, проверить записки или зарядить телефон при работающем электричестве."

func interact(id: String) -> bool:
	var s: ApartmentState = host.state
	match id:
		"jacket":
			s.mark("jacket_checked")
			host.read_document("pocket_note")
		"key_rack":
			if s.mark("study_key"):
				InventoryManager.add_item("study_key", "Ключ от кабинета", 1, "", "Снят с кухонной ключницы. Кабинет — за галереей.")
				host.ui.message("Кухонная ключница", "На одном из крючков ключ с потёртой биркой «Кабинет». Остальные пусты. Кто-то недавно снял всю связку.")
			else: host.ui.notify("Ключ от кабинета уже в сумке. На крючках больше ничего нет.")
		"study_door", "study_door_side":
			if s.has("study_unlocked"): host.ui.notify("Кабинет открыт. Боковой проход ведёт в задний коридор.")
			elif not InventoryManager.has_item("study_key"): host.ui.message("Кабинет заперт", "Под ручкой старая царапина. Подойдёт маленький ключ с биркой. Обычно он висел в ключнице у кухни.")
			else:
				s.mark("study_unlocked")
				InventoryManager.remove_item("study_key")
				host.world.set_study_open(true)
				SoundManager.play_door_unlock()
				host.ui.message("За дверью", "Пахнет пылью и остывшим чаем. Стул отодвинут, на столе разложены бумаги. Я точно оставляла здесь запасные ключи.", host.checkpoint)
		"key_cabinet":
			if s.has("cabinet_unlocked"): host.ui.notify("Картотека открыта. Входной ключ уже в сумке, приписка указывает на диван.")
			else:
				s.mark("cabinet_checked")
				pin_panel()
		"desk_note": host.read_document("desk_note")
		"wall_clock":
			s.mark("clock_seen")
			host.read_document("clock_note")
		"microwave":
			s.mark("outage_seen")
			host.read_document("outage_note")
		"service_log": host.read_document("service_log")
		"sofa_search":
			s.mark("sofa_searched")
			host.read_document("diary")
		"front_key":
			if not s.has("cabinet_unlocked"): host.ui.notify("Запасной входной ключ убран в картотеку кабинета.")
			else: return false
		"diary":
			if not s.has("sofa_searched"): host.ui.notify("Личных записей на виду нет. Проверьте, куда вчера убрали дневник.")
			else: return false
		"tap":
			s.mark("tap_closed")
			host.ui.message("Кран", "Один оборот — и капли перестают падать. В наступившей тишине особенно отчётливо слышен шорох за стеной. На зеркале красные буквы.")
		"books": host.ui.message("Книжная полка", "Книги стоят не по алфавиту: детективы рядом с руководством по ремонту. Одну достали и поставили корешком внутрь. Между страниц засох листок с осенней прогулки.")
		"records":
			s.mark("record_checked")
			if s.has("power"):
				s.flags["record_playing"] = not s.has("record_playing")
				host.ui.message("Проигрыватель", "Диск сделал оборот, игла тихо зашуршала. Я помню эту мелодию, но не помню, кто включал её вчера." if s.has("record_playing") else "Игла поднялась. Без мелодии шорохи в квартире кажутся громче.")
			else: host.ui.message("Проигрыватель", "Игла оставлена на дорожке. На конверте чужим почерком: «Эту ты точно узнаешь». Электропитание отключено.")
		"photo": host.ui.message("Фотография", "Даша с друзьями у воды. Одно лицо закрыто бликом от треснувшего стекла. На обороте: «В следующий раз соберёмся у тебя». Никакого объяснения тому, что происходит сейчас.")
		"laundry": host.ui.message("Стиральная машина", "Внутри мокрое полотенце и чужой тёмный шарф. В кармане куртки остался скомканный чек; его уже положили на рабочий стол. Барабан не запускали после отключения.")
		"pantry": host.ui.message("Кладовая", "Зимние ботинки, банки с краской, коробка старых проводов. На стене виден прямоугольник от снятой фотографии. Ящик с инструментами перенесли в постирочную.")
		"meal": host.ui.message("Два прибора", "Две тарелки. В одной чайной чашке осел тёмный след, другая осталась чистой. Я кого-то ждала. Почему тогда не помню ни одного лица за столом?")
		"coat_hook": host.ui.message("Крючки", "В пыли видны свежие полосы. Здесь висело больше вещей, чем сейчас. Под одной вешалкой обрывок нитки того же цвета, что и шарф в постирочной.")
		_: return false
	SoundManager.play_material_interact("wood")
	host._refresh_world()
	return true

func pin_panel() -> void:
	var ui: ApartmentUI = host.ui
	ui.open("cabinet", "Картотека · четыре цифры", "На полоске бумаги: «Время, когда погас свет. Старым часам не верь». Кухонная записка и журнал в постирочной помогут вспомнить вечер.")
	if not pin_error.is_empty(): ui.add_label(ui.content, pin_error, 17, Color("d9a395"))
	var row: HBoxContainer = HBoxContainer.new()
	ui.content.add_child(row)
	for i: int in 4:
		ui.button(str(pin[i]) + "  ↻", func() -> void: pin[i] = (pin[i] + 1) % 10; pin_panel(), row)
	ui.add_label(ui.content, "Можно ввести четыре цифры с клавиатуры. Проверить — " + ui.key("interact"), 15, Color("9fb3b8"))
	ui.button("Проверить замок", func() -> void: try_pin())
	ui.button("Вернуться к поиску", ui.close)

func enter_digit(value: int) -> void:
	pin[active_digit] = value
	active_digit = (active_digit + 1) % 4
	pin_error = ""
	pin_panel()

func quest_log() -> Array[Dictionary]:
	var s: ApartmentState = host.state
	var entries: Array[Dictionary] = []
	for row: Array in [["exit_checked", "Проверить выход · прихожая", s.has("dose")], ["jacket_checked", "Проверить карманы куртки · спальня", s.has("exit_checked")], ["study_key", "Найти ключницу · кухня", s.has("jacket_checked")], ["study_unlocked", "Открыть кабинет · за галереей", s.has("study_key")], ["cabinet_checked", "Осмотреть картотеку · кабинет", s.has("study_unlocked")], ["outage_seen", "Сопоставить время · кухня и постирочная", s.has("cabinet_checked")], ["cabinet_unlocked", "Открыть картотеку и взять ключ", s.has("cabinet_checked")], ["sofa_searched", "Найти личный дневник · гостиная", s.has("cabinet_unlocked")], ["latch_released", "Освободить засов · входная дверь", not s.diary_choice.is_empty()], ["coat", "Попытаться покинуть квартиру", s.has("latch_released")]]:
		if row[2] or s.has(row[0]): entries.append({"text": row[1], "complete": s.has(row[0])})
	return entries

func try_pin() -> bool:
	if pin != [2, 1, 1, 7]:
		attempts += 1
		pin_error = "Замок не поддался. Нужны четыре цифры времени: часы и минуты."
		pin_panel()
		return false
	host.ui.close()
	host.state.mark("cabinet_unlocked")
	host._pickup("front_key", "Ключ от входной двери", "Найден в запертой картотеке кабинета.", "metal")
	host.read_document("cabinet_note")
	return true

func exit_blocker() -> bool:
	var s: ApartmentState = host.state
	if s.phase in ["encounter", "resolved", "complete"] or s.has("coat"): return false
	if s.mark("exit_checked"):
		host.ui.message("Входная дверь", "Ключ подходит к замку, но верхний засов перекосило. Нужно разобраться с пластиной под крышкой." if s.has("front_key") else "Замок закрыт, ключа в нём нет. Верхний засов перекосило. Сначала нужно найти свою связку — обычно она в куртке у спальни.")
		return true
	if not s.has("front_key"):
		host.ui.notify(details())
		return true
	if s.diary_choice.is_empty(): return false
	if not s.has("latch_released"):
		if not InventoryManager.has_item("screwdriver"):
			host.ui.message("Верхний засов", "Ключ поворачивается, но перекошенная пластина не даёт сдвинуть засов. Нужна отвёртка из рабочего ящика в постирочной.")
		else: latch_panel()
		return true
	return false

func latch_panel() -> void:
	var ui: ApartmentUI = host.ui
	ui.open("latch", "Перекошенный засов", "Крышка снята. Три риски показывают, куда должны попасть ползуны: правый край · левый край · середина. Подберите положения, затем сдвиньте пластину.")
	if not latch_error.is_empty(): ui.add_label(ui.content, latch_error, 17, Color("d9a395"))
	var row: HBoxContainer = HBoxContainer.new()
	ui.content.add_child(row)
	for i: int in 3:
		ui.button(["● — —", "— ● —", "— — ●"][latch[i]], func() -> void: latch[i] = (latch[i] + 1) % 3; latch_panel(), row)
	ui.button("Сдвинуть пластину", func() -> void: try_latch())
	ui.button("Отложить", ui.close)

func try_latch() -> bool:
	if latch != [2, 0, 1]:
		latch_error = "Пластина упирается в ползун. Сопоставьте положения с рисками."
		latch_panel()
		return false
	host.state.mark("latch_released")
	host.ui.close()
	host.ui.message("Засов освободился", "Металл поддался. Ключ подходит. Теперь я действительно могу выйти. За дверью на секунду стихли шаги.", host.checkpoint)
	return true

func power_panel() -> void:
	var ui: ApartmentUI = host.ui
	ui.open("repair", "Щиток · проверить линии", "Отвёртка снимает крышку. Новый предохранитель пока не установлен. Записка электрика: «Жилая и кухонная линии рабочие. Ванная даёт короткое — оставить отключённой».")
	if not power_error.is_empty(): ui.add_label(ui.content, power_error, 17, Color("d9a395"))
	var row: HBoxContainer = HBoxContainer.new()
	ui.content.add_child(row)
	for i: int in 3:
		ui.button(["Комнаты", "Кухня", "Ванная"][i] + (" · ВКЛ" if breakers[i] else " · ВЫКЛ"), func() -> void: breakers[i] = not breakers[i]; power_panel(), row)
	ui.button("Установить вставку и включить", func() -> void: try_power())
	ui.button("Позже", ui.close)

func try_power() -> bool:
	if breakers != [true, true, false]:
		power_error = "Автомат не держится. Проверьте линии. Вставка пока цела."
		power_panel()
		return false
	if not InventoryManager.has_item("screwdriver") or not InventoryManager.has_item("fuse"): return false
	host.ui.close()
	host.state.mark("power")
	InventoryManager.remove_item("fuse")
	SoundManager.play_door_unlock()
	host.ui.message("Электричество вернулось", "Из кухни отозвался холодильник. Свет выхватил пятна на полу и чужую чашку на столе. Телефон теперь можно зарядить; накопленная тревога осталась.", host.checkpoint)
	return true
