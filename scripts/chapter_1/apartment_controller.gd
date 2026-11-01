extends Node2D

const State: GDScript = preload("res://scripts/chapter_1/chapter_state.gd")
const World: GDScript = preload("res://scripts/chapter_1/apartment_world.gd")
const Screen: GDScript = preload("res://scripts/chapter_1/apartment_ui.gd")
const Enemy: GDScript = preload("res://scripts/chapter_1/apartment_enemy.gd")
const PlayerScript: GDScript = preload("res://scripts/player.gd")
const TorchScript: GDScript = preload("res://scripts/flashlight.gd")
const Story: GDScript = preload("res://scripts/chapter_1/apartment_story.gd")
const Atmosphere: GDScript = preload("res://scripts/chapter_1/apartment_atmosphere.gd")
const CHARGE_SECONDS: float = 20.0
const DARKNESS_GRACE: float = 12.0
const DARKNESS_STRESS_PER_SECOND: float = 0.12

var state: ApartmentState = ApartmentState.new()
var world: ApartmentWorld
var player: CharacterBody2D
var flashlight: Flashlight
var ui: ApartmentUI
var enemy: ApartmentEnemy
var documents: Dictionary = {}
var selected: String = ""
var hidden_player: bool = false
var sneaking: bool = false
var dark_time: float = 0.0
var thought_time: float = 25.0
var blind_cooldown: float = 0.0
var tutorial_gate: StaticBody2D
var silhouette: Polygon2D
var phone_light: PointLight2D
var phone_glow_time: float = 0.0
var blind_exposure: float = 0.0
var intro_active: bool = false
var intro_skip_requested: bool = false
var intro_pan: Tween
var marker: Line2D
var marker_title: Label
var illusion_time: float = 0.0
var story: RefCounted

func _ready() -> void:
	SoundManager.stop_bg_music()
	RenderingServer.set_default_clear_color(Color("0b111b"))
	get_viewport().get_window().min_size = Vector2i(960, 600)
	documents = JSON.parse_string(FileAccess.get_file_as_string("res://resources/chapter_1/documents.json"))
	ParanoiaManager.is_active = true
	ParanoiaManager.is_decay_active = false
	world = World.new()
	add_child(world)
	world.build()
	story = Story.new()
	story.setup(self)
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.color = Color(0.60, 0.65, 0.76)
	add_child(ambient)
	_build_player()
	_build_gate()
	phone_light = world.light(world.interactables.phone.position, Color("99c9e8"), 0.6, 0.42)
	phone_light.enabled = false
	silhouette = world.polygon(world, PackedVector2Array([Vector2(-18, 0), Vector2(-16, -65), Vector2(-7, -78), Vector2(6, -78), Vector2(18, -60), Vector2(20, 0)]), Color("242331"))
	silhouette.position = ApartmentWorld.iso(Vector2(530, 150))
	silhouette.visible = false
	ui = Screen.new()
	add_child(ui)
	ui.setup(self)
	var atmosphere: Node2D = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(self)
	marker = world.line(world, PackedVector2Array([Vector2(-18, 0), Vector2(0, 9), Vector2(18, 0), Vector2(0, -9), Vector2(-18, 0)]), Color("d5c596"), 2)
	marker.z_index = -15
	marker_title = world.label(marker, Vector2(-80, -42), "", 14, Color("e9d8b3"))
	marker.visible = false
	SaveManager.toast_requested.connect(ui.notify)
	InventoryManager.item_used.connect(_on_item_used)
	if not SaveManager.apply_pending_save_if_any(self):
		InventoryManager.reset_inventory()
		ClueManager.reset_all_clues()
		ParanoiaManager.set_paranoia(24.0)
		_intro.call_deferred()
	else:
		$BootCurtain.queue_free()
		_refresh_world()

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = ApartmentWorld.iso(Vector2(320, 300))
	player.speed = 205.0
	player.collision_layer = 4
	player.collision_mask = 3
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "DashaSprite"
	sprite.texture = preload("res://assets/sprites/dasha.png")
	sprite.scale = Vector2(0.28, 0.28)
	sprite.offset = Vector2(0, -228)
	sprite.light_mask = 4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(sprite)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	collision.shape = circle
	player.add_child(collision)
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.05, 1.05)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	flashlight = TorchScript.new()
	flashlight.name = "Flashlight"
	flashlight.is_flashlight_on = false
	flashlight.available = false
	player.add_child(flashlight)
	world.add_child(player)
	# The held lamp lights the room; the actor has its own readable fill channel.
	flashlight.cone_light.range_item_cull_mask = 1
	flashlight.ambient_light.range_item_cull_mask = 1
	var actor_light: PointLight2D = world.light(Vector2.ZERO, Color("d2d8ee"), 0.8, 0.6)
	world.remove_child(actor_light)
	player.add_child(actor_light)
	actor_light.range_item_cull_mask = 4
	actor_light.shadow_enabled = false
	actor_light.position = Vector2(0, -40)

func _build_gate() -> void:
	# The bedroom doorway remains physically open during the tutorial.
	pass

func _intro() -> void:
	if state.has("intro"):
		return
	state.mark("intro")
	intro_active = true
	ParanoiaManager.set_paranoia(38.0)
	player.set_control_locked(true)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.top_level = true
	camera.global_position = ApartmentWorld.iso(Vector2(250, 120))
	camera.reset_smoothing()
	await ui.opening_fade()
	if not intro_skip_requested:
		ui.cinematic_caption("Накануне вечером в квартире погас свет.")
		await _intro_wait(4.5)
	if not intro_skip_requested:
		intro_pan = create_tween()
		intro_pan.tween_property(camera, "global_position", world.interactables.phone.global_position, 1.6)
		ui.cinematic_caption("Телефон разрядился. Последние часы словно выпали из памяти.")
		await _intro_wait(5.0)
	if not intro_skip_requested:
		intro_pan = create_tween()
		intro_pan.tween_property(camera, "global_position", player.global_position, 1.6)
		ui.cinematic_caption("Даша просыпается от холода. За стеной слышен шорох.")
		await _intro_wait(4.5)
	if intro_pan: intro_pan.kill()
	camera.top_level = false
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	ui.cinematic_caption("")
	intro_active = false
	ui.hide_intro_skip()
	if intro_skip_requested:
		_finish_opening()
		return
	ui.message("Тёмная квартира · Даша", "Я проснулась от холода. В квартире темно, за окном дождь. Последнее, что помню, — вчерашний вечер. Почему дверь в коридор открыта?", func() -> void:
		ui.message("Даша", "Телефон разрядился. Свет опять выбило… Нужно понять, что произошло, и найти свои ключи.", func() -> void:
			silhouette.visible = true
			ParanoiaManager.set_paranoia(100.0)
			player.apply_shake(2.0)
			ui.message("В углу кто-то стоит", "Не двигайся… Нет. Это куртка на стуле. От тревоги знакомые вещи кажутся чужими. Такие приступы уже были — таблетки должны лежать у кровати.", func() -> void:
				_finish_opening()
			)
		)
	)

func _intro_wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not intro_skip_requested:
		await get_tree().process_frame
		if not get_tree().paused: elapsed += get_process_delta_time()

func skip_intro() -> void:
	if intro_active: intro_skip_requested = true

func _finish_opening() -> void:
	silhouette.visible = false
	ParanoiaManager.set_paranoia(100.0)
	state.mark("opening_done")
	ui.hud.visible = true
	player.set_control_locked(false)
	ui.notify("От тревоги знакомые вещи кажутся чужими. Таблетка помогает справиться с приступом; запас ограничен.", 7.0)

func is_blocked() -> bool:
	return intro_active or ui == null or not ui.modal_kind.is_empty() or get_tree().paused

func current_goal() -> String:
	if story != null:
		var next: String = story.goal()
		if not next.is_empty(): return next
	if not state.has("bed"): return "Обыщите кровать"
	if not state.has("pills"): return "Подберите таблетки"
	if not state.has("dose"): return "Примите таблетку · " + ui.key("toggle_inventory")
	if state.phase == "complete": return "Квартира осталась позади"
	if state.phase == "encounter": return "Найдите способ уйти"
	if state.phase == "resolved": return "Выйдите из квартиры"
	if not state.has("front_key"): return "Найдите входной ключ"
	if state.diary_choice.is_empty(): return "Осмотрите дневник в гостиной"
	return "Вернитесь к входной двери"

func goal_details() -> String:
	if story != null and state.has("dose") and state.phase not in ["encounter", "resolved", "complete"]: return story.details()
	if not state.has("bed"): return "Обыщите кровать — таблетки помогут справиться с искажениями."
	if not state.has("pills"): return "Подберите блистер у кровати. В нём две таблетки."
	if not state.has("dose"): return "Откройте инвентарь [%s] и примите одну таблетку." % ui.key("toggle_inventory")
	if state.phase == "complete": return "Тёмная квартира · сцена завершена"
	if state.phase == "encounter": return "Спаситесь: отвлеките незнакомца и уйдите либо обезвредьте его."
	if state.phase == "resolved": return "Путь свободен. Вернитесь к входной двери."
	if not state.has("front_key"): return "Найдите входной ключ в спальне. Осмотрите листок у кровати."
	if state.diary_choice.is_empty(): return "Исследуйте квартиру. Найдите дневник в гостиной и решите, верить ли ему."
	if state.diary_choice == "trust" and not state.has("pepper"): return "Защита по желанию: ключ под разбитой вазой → шкаф. Входная дверь уже доступна."
	if not state.has("coat"): return "Можно уходить. По желанию: почините щиток, зарядите телефон, найдите защиту."
	return "Пальто осталось на полу. Подойдите к двери, когда будете готовы выйти."

func _process(delta: float) -> void:
	if not is_instance_valid(player) or ui == null:
		return
	flashlight.input_enabled = not is_blocked() and not hidden_player
	world.update_lighting(player.position, Vector2.RIGHT.rotated(flashlight.rotation), flashlight.is_emitting(), state.has("power"), flashlight.emission_position(), flashlight.emission_height())
	if is_blocked():
		return
	if not state.has("intro"):
		_intro()
		return
	blind_cooldown = maxf(0.0, blind_cooldown - delta)
	phone_glow_time = maxf(0.0, phone_glow_time - delta)
	phone_light.enabled = phone_glow_time > 0.0
	if state.has("phone_charging") and not state.has("phone_ready"):
		state.charge = minf(CHARGE_SECONDS, state.charge + delta)
		if state.charge >= CHARGE_SECONDS:
			state.mark("phone_ready")
			ui.notify("Телефон зарядился. Вернитесь к тумбочке: сохранённые сообщения доступны. Связи нет.", 8.0)
	var protected_from_dark: bool = state.has("power") or flashlight.is_emitting() or world.room_at(player.position) == "bedroom"
	if protected_from_dark:
		dark_time = 0.0
	else:
		dark_time += delta
		if dark_time > DARKNESS_GRACE and state.has("dose"):
			ParanoiaManager.add_paranoia(delta * DARKNESS_STRESS_PER_SECOND * (1.0 + state.belief / 100.0), "Темнота")
	thought_time -= delta
	illusion_time = maxf(0.0, illusion_time - delta)
	if illusion_time <= 0.0: silhouette.visible = false
	if thought_time <= 0.0:
		thought_time = 45.0
		if ParanoiaManager.get_paranoia() + state.belief * 0.5 > 80.0:
			ui.notify("«Кажется, шаги повторяются за мной…» · мысль Даши" if state.belief > 20 else "«Я слышу слишком много в этой тишине. Нужно проверить факты». · мысль Даши")
			if state.belief > 20.0:
				var direction: Vector2 = Vector2.RIGHT.rotated(flashlight.rotation + 1.35)
				var candidate: Vector2 = player.position + direction * 240.0
				if world.can_walk(candidate) and world.clear_line(player.position, candidate):
					silhouette.position = candidate
					silhouette.modulate.a = 0.45
					silhouette.visible = true
					illusion_time = 0.65
		elif not protected_from_dark:
			ui.notify("Темнота медленно усиливает стресс. Найдите фонарик или восстановите электричество.")
	sneaking = Input.is_action_pressed("sneak")
	player.movement_mode = "sneak" if sneaking else ("run" if Input.is_action_pressed("run") else "walk")
	player.speed = {"sneak": 90.0, "walk": 205.0, "run": 325.0}[player.movement_mode]
	if hidden_player:
		player.set_control_locked(true)
	_update_target()
	if state.phase == "encounter" and is_instance_valid(enemy) and flashlight.is_emitting() and blind_cooldown <= 0.0:
		var towards: Vector2 = player.position.direction_to(enemy.position)
		var aimed: bool = towards.dot(Vector2.RIGHT.rotated(flashlight.rotation)) > 0.92
		if aimed and player.position.distance_to(enemy.position) < 310 and world.clear_line(player.position, enemy.position):
			blind_exposure += delta
			if blind_exposure > 1.5:
				blind_enemy()
		else:
			blind_exposure = 0.0

func _update_target() -> void:
	selected = ""
	var nearest: float = 94.0
	for id: String in world.interactables:
		var object: Node2D = world.interactables[id]
		if not object.visible or not _target_available(id): continue
		var distance: float = player.position.distance_to(object.position)
		if distance < nearest and world.clear_line(player.position, object.position, false):
			nearest = distance
			selected = id
	if hidden_player:
		ui.prompt.text = "[%s] Выйти из укрытия" % ui.key("interact")
	elif is_instance_valid(enemy) and enemy.mode == ApartmentEnemy.Mode.STUNNED and player.position.distance_to(enemy.position) < 95.0:
		selected = "enemy"
		ui.prompt.text = "[%s] Оглушён · действия" % ui.key("interact")
	elif not selected.is_empty():
		ui.prompt.text = "[%s] %s" % [ui.key("interact"), world.interactables[selected].get_meta("title")]
	else:
		ui.prompt.text = ""
	marker.visible = not selected.is_empty() and selected != "enemy"
	if marker.visible:
		marker.position = world.interactables[selected].position
		marker_title.text = ""

func _target_available(id: String) -> bool:
	if id == "key_rack": return not state.has("study_key")
	if id == "sofa_search": return not state.has("sofa_searched")
	if id in ["pills", "front_key", "flashlight", "phone", "cupboard_key", "screwdriver", "fuse", "throwable", "rope", "heavy"]:
		return not state.has(id)
	if id == "vase": return not state.has("vase")
	if id == "coat_trap": return not state.has("coat_trap")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if is_blocked(): return
	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if hidden_player:
			hidden_player = false
			player.modulate.a = 1.0
			player.set_control_locked(false)
		elif not selected.is_empty():
			interact(selected)
	elif event.is_action_pressed("quick_save") and not event.is_echo():
		SaveManager.save_game("slot_1")
	elif event.is_action_pressed("quick_load") and not event.is_echo():
		SaveManager.load_game("slot_1")
	elif event.is_action_pressed("use_tool") and not event.is_echo():
		use_pepper()
	elif event.is_action_pressed("throw_item") and not event.is_echo():
		throw_vase(get_global_mouse_position())
	elif event.is_action_pressed("blind") and not event.is_echo():
		blind_enemy()

func interact(id: String) -> void:
	if is_blocked() or not _target_available(id): return
	if story.interact(id): return
	if world.interactables.has(id):
		SoundManager.play_material_interact(world.interactables[id].get_meta("kind", "wood"))
	match id:
		"bed":
			if state.mark("bed"):
				world.interactables.pills.visible = true
				ui.notify("Под одеялом блистер. В нём две таблетки. Подберите его у кровати.", 8.0)
			else: ui.notify("Блистер лежит рядом с кроватью." if not state.has("pills") else "Здесь больше нет таблеток.")
		"pills":
			if state.has("bed"):
				_pickup("pills", "Седативное", "Одна доза снижает стресс на 40. Всего две таблетки на начало игры.", "plastic", 2, true)
		"front_key": _pickup(id, "Ключ от входной двери", "Подходит к замку в прихожей.", "metal")
		"flashlight":
			_pickup(id, "Фонарик", "Направляйте мышью. Свет останавливает страх темноты. Длительный луч ослепляет незнакомца.", "metal")
			flashlight.available = true
			flashlight.toggle_flashlight(true)
		"phone":
			_pickup(id, "Мобильный телефон", "Разряжен. Кабель на тумбочке; для зарядки нужно электричество.", "plastic")
			phone_glow_time = 3.0
			ui.message("Экран гаснет · 0%", "На секунду вспыхивает пустая батарея. Связи нет. После ремонта щитка можно зарядить телефон на тумбочке и прочитать сохранённые сообщения. Для выхода это не обязательно.")
		"vase":
			state.mark("vase")
			world.interactables.cupboard_key.visible = true
			ui.notify("Под осколками блеснул маленький ключ от шкафа. Теперь его можно подобрать.")
		"cupboard_key":
			if state.has("vase"): _pickup(id, "Ключ от шкафа", "Маленький ключ найден под разбитой вазой.", "metal")
		"cupboard":
			if not InventoryManager.has_item("cupboard_key") and not state.has("cupboard"):
				ui.notify("Шкаф заперт. Дневник упоминает маленький ключ у разбитой вазы в гостиной.")
			elif state.mark("cupboard"):
				InventoryManager.remove_item("cupboard_key")
				state.mark("pepper")
				InventoryManager.add_item("pepper", "Перцовый баллончик", 1, "", "Один заряд. Во время встречи применить на близкой дистанции, глядя на противника. [%s]" % ui.key("use_tool"), false)
				ui.notify("В шкафу баллончик и старое пальто на вешалке. Баллончик в инвентаре.")
			else: ui.notify("Пустой шкаф. Пальто осталось на полу." if state.has("coat") else "На крючке висит старое пальто.")
		"screwdriver": _pickup(id, "Отвёртка", "Открывает крышку щитка в кладовой.", "metal")
		"fuse": _pickup(id, "Новый предохранитель", "Подходит к щитку в кладовой.", "metal")
		"fusebox": _repair_power()
		"charger": _charge_phone()
		"throwable": _pickup(id, "Керамическая ваза", "Целая ваза для отвлечения. Бросок к курсору: [%s]." % ui.key("throw_item"), "glass")
		"rope": _pickup(id, "Бельевой шнур", "Позволяет надёжно связать оглушённого незнакомца.", "plastic")
		"heavy": _pickup(id, "Чугунная сковорода", "Тяжёлый предмет. Удар по голове может убить. Действие требует отдельного подтверждения.", "metal")
		"bedside", "diary", "hall_mirror", "bathroom", "bath_note": read_document(id)
		"exit": attempt_exit()
		"hide_bath", "hide_sofa": enter_hiding()
		"enemy": enemy_choices()
		"coat_trap":
			if is_instance_valid(enemy) and player.position.distance_to(enemy.position) < 135:
				state.mark("coat_trap")
				enemy.stun(7.0)
				ui.notify("Даша толкнула вешалку ему под ноги. Он потерял равновесие — можно уйти или обезвредить его.")
			else: ui.notify("Вешалку можно толкнуть под ноги незнакомцу, когда он приблизится.")
	_refresh_world()

func _pickup(id: String, title: String, description: String, material_type: String, amount: int = 1, usable: bool = false) -> void:
	if not state.mark(id): return
	InventoryManager.add_item(id, title, amount, "", description, usable)
	SoundManager.play_material_interact(material_type)
	_refresh_world()

func _on_item_used(id: String, success: bool) -> void:
	if id == "pills" and success and state.mark("dose"):
		if is_instance_valid(tutorial_gate): tutorial_gate.queue_free()
		ui.notify("Таблетка снизила стресс. Одна доза осталась. Теперь можно исследовать квартиру. Свет не заменяет таблетки.", 10.0)
		# UI closes the inventory before this deferred checkpoint is taken.
		checkpoint.call_deferred()

func read_document(id: String) -> void:
	if not state.documents.has(id):
		state.documents.append(id)
		ClueManager.register_document(id, documents[id])
		if id in ["hall_mirror", "bathroom"]:
			ParanoiaManager.add_paranoia(4.0 + state.belief * 0.06, "Надпись")
	ui.document(id)

func choose_diary(value: String) -> void:
	if state.choose(value):
		ParanoiaManager.add_paranoia(8.0 if value == "trust" else 2.0, "Решение о дневнике")
		ui.notify("«Нужно защититься». Баллончик уже найден." if state.has("pepper") and value == "trust" else "Решение записано в дневник. Предметы остаются доступны в обеих ветках.")
		checkpoint()

func _repair_power() -> void:
	if state.has("power"):
		ui.notify("Щиток исправен. Свет включён, зарядка работает.")
		return
	var missing: Array[String] = []
	if not InventoryManager.has_item("screwdriver"): missing.append("отвёртка из кладовой")
	if not InventoryManager.has_item("fuse"): missing.append("предохранитель из кухни")
	if not missing.is_empty():
		ui.message("Перегоревшая вставка", "Для ремонта нужны: %s.\n\nРемонт необязателен: можно искать вещи с фонариком. Электричество даст свет во всей квартире и позволит зарядить телефон." % ", ".join(missing))
		return
	story.power_panel()

func _charge_phone() -> void:
	if not state.has("phone"):
		ui.notify("Сначала возьмите телефон у тумбочки.")
	elif not state.has("power"):
		ui.notify("В розетке нет тока. Нужны отвёртка из кладовой и предохранитель из кухни, затем ремонт щитка.", 7.0)
	elif state.has("phone_ready"):
		ui.open("phone", "Телефон · 12% · НЕТ СЕТИ", "Доступны только сохранённые данные. Связи нет, позвонить нельзя.")
		ui.button("Сохранённые сообщения", func() -> void: read_document("messages"))
		ui.button("Вчерашняя заметка", func() -> void: read_document("phone_note"))
		ui.button("Положить телефон", ui.close)
	elif state.mark("phone_charging"):
		ui.notify("Телефон подключён. Зарядка займёт 20 секунд игрового времени. Можно продолжить поиск.", 7.0)
	else: ui.notify("Телефон заряжается · %d%%" % roundi(state.charge / CHARGE_SECONDS * 100.0))

func attempt_exit() -> void:
	if not state.has("dose"):
		ui.message("Даша", "Сердце колотится, трудно сосредоточиться на замке. Я могу осмотреть квартиру, но перед выходом нужно прийти в себя: таблетки у кровати.")
		return
	if story.exit_blocker(): return
	if not state.has("front_key"):
		ui.notify("Нужен ключ от входной двери. Он в спальне, в кармане куртки возле кровати.")
		return
	if state.diary_choice.is_empty():
		ui.notify("Я должна разобраться в записях. Прочитайте дневник в гостиной и выберите отношение к нему.")
		return
	if state.phase == "encounter":
		if can_escape(): finish_scene("stealth")
		else: ui.notify("Он видит меня у двери. Нужно отвлечь его, оглушить или скрыться и вернуться.")
		return
	if state.phase == "resolved":
		finish_scene(state.outcome)
		return
	if not state.has("coat"):
		checkpoint()
		ui.begin_qte()
		player.apply_shake(5.0)
		return
	ui.open("confirm_exit", "Ключ в замке", "Я могу ещё осмотреть квартиру. Если поверну ключ, придётся выйти.")
	ui.button("Повернуть ключ", func() -> void: ui.close(); begin_encounter())
	ui.button("Вернуться к поиску", ui.close)

func finish_coat() -> void:
	state.mark("coat")
	state.phase = "coat_done"
	_refresh_world()
	ui.message("Пальто и вешалка", "Это просто старое пальто. Крючок выскочил, вешалка придавила плечо. Никого под тканью нет.\n\nДаша: «Нужно было посмотреть внимательнее…»\n\nВешалка остаётся на полу. Её можно толкнуть под ноги тому, кто подойдёт слишком близко.", checkpoint)

func begin_encounter() -> void:
	if state.phase == "encounter" or not state.has("coat"): return
	checkpoint()
	state.phase = "encounter"
	_spawn_enemy()
	ParanoiaManager.add_paranoia(10.0, "Незнакомец")
	ui.message("Ручку дёрнули снаружи", "За дверью человек. На нём маска, в руках ничего нет. Он шагнул в квартиру и перекрыл проход.\n\nДаша: «Кто вы? Не подходите!»\n\nДержите дистанцию. Можно ослепить его направленным фонариком, применить перец, бросить целую вазу к курсору или толкнуть вешалку рядом со шкафом. Оглушённого можно связать найденным шнуром. Тихий обход через гостиную, галерею и кухню позволяет вернуться к двери, пока он ищет вас.\n\nВ паузе можно вернуться к контрольной точке перед встречей.")

func _spawn_enemy() -> void:
	if is_instance_valid(enemy):
		enemy.free()
	enemy = Enemy.new()
	enemy.setup(self)
	world.add_child(enemy)
	enemy.position = ApartmentWorld.iso(Vector2(810, 100))

func can_escape() -> bool:
	return is_instance_valid(enemy) and (enemy.mode in [ApartmentEnemy.Mode.STUNNED, ApartmentEnemy.Mode.RESTRAINED, ApartmentEnemy.Mode.DEAD] or (enemy.position.distance_to(player.position) > 220.0 and not enemy.sees_player()))

func use_pepper() -> bool:
	if state.phase != "encounter" or not is_instance_valid(enemy) or not InventoryManager.has_item("pepper"):
		ui.notify("Баллончик нужен во время встречи и расходуется только при попадании.")
		return false
	var towards: Vector2 = player.position.direction_to(enemy.position)
	if enemy.position.distance_to(player.position) > 150.0 or towards.dot(Vector2.RIGHT.rotated(flashlight.rotation)) < 0.55 or not world.clear_line(player.position, enemy.position):
		ui.notify("Подойдите ближе и направьте курсор на незнакомца. Препятствия перекрывают струю.")
		return false
	InventoryManager.remove_item("pepper")
	enemy.stun(12.0)
	SoundManager.play_material_interact("plastic")
	ui.notify("Перец попал в лицо. Заряд израсходован. Есть время уйти или связать незнакомца.")
	return true

func blind_enemy() -> bool:
	if state.phase != "encounter" or not is_instance_valid(enemy) or not flashlight.is_emitting() or blind_cooldown > 0:
		return false
	var towards: Vector2 = player.position.direction_to(enemy.position)
	if player.position.distance_to(enemy.position) > 310 or towards.dot(Vector2.RIGHT.rotated(flashlight.rotation)) < 0.86 or not world.clear_line(player.position, enemy.position):
		ui.notify("Направьте включённый фонарик на незнакомца. Стены и мебель перекрывают луч.")
		return false
	enemy.stun(5.0)
	blind_cooldown = 9.0
	blind_exposure = 0.0
	ui.notify("Он закрыл лицо от луча. Несколько секунд, чтобы отойти или обезвредить его.")
	return true

func throw_vase(target: Vector2) -> bool:
	if state.phase != "encounter" or not InventoryManager.has_item("throwable"):
		ui.notify("Для отвлечения нужна целая ваза из гостиной. Бросок доступен во время встречи.")
		return false
	var point: Vector2 = player.position + (target - player.position).limit_length(520.0)
	if not world.can_walk(point, 10.0) or not world.clear_line(player.position, point):
		ui.notify("Туда нельзя бросить: путь перекрыт. Выберите свободный участок пола.")
		return false
	InventoryManager.remove_item("throwable")
	var shards: Node2D = world.box("ThrownVase", Rect2(ApartmentWorld.grid(point) - Vector2(15, 15), Vector2(30, 30)), 2, Color("9cb5c6"), "", false)
	shards.z_index = -1
	SoundManager.play_material_interact("glass")
	enemy.hear(point)
	ui.notify("Ваза разбилась. Он идёт на звук. Выключите фонарик и двигайтесь крадучись.")
	return true

func enter_hiding() -> void:
	if state.phase != "encounter":
		ui.notify("Здесь можно укрыться, если кто-то будет искать меня.")
	elif flashlight.is_emitting():
		ui.notify("Сначала выключите фонарик: луч выдаёт укрытие.")
	elif enemy.sees_player():
		ui.notify("Он видит, куда я прячусь. Сначала разорвите линию видимости за стеной.")
	else:
		hidden_player = true
		player.modulate.a = 0.35
		player.set_control_locked(true)
		ui.notify("Даша затаилась. Незнакомец проверит последнее известное место и продолжит поиск.")

func enemy_choices() -> void:
	if enemy.mode != ApartmentEnemy.Mode.STUNNED: return
	ui.open("enemy_choice", "Он оглушён", "Можно отойти и уйти. Обезвредить его шнуром — нелетальный исход. Тяжёлый удар может привести к смерти и повлияет на дальнейшую историю.")
	if InventoryManager.has_item("rope"):
		ui.button("Связать бельевым шнуром", func() -> void: ui.close(); resolve_enemy("restrained"))
	else: ui.add_label(ui.content, "Чтобы связать, нужен бельевой шнур с полки в гостиной.", 18)
	if InventoryManager.has_item("heavy"):
		ui.button("Ударить сковородой · опасно для жизни", func() -> void:
			ui.open("lethal_confirm", "Необратимое решение", "Удар тяжёлым предметом по голове может убить. Продолжить?")
			ui.button("Нанести смертельный удар", func() -> void: ui.close(); resolve_enemy("lethal"))
			ui.button("Отойти", ui.close)
		)
	if player.position.distance_to(world.interactables.exit.position) < 110.0 and can_escape():
		ui.button("Ускользнуть в дверь", func() -> void: ui.close(); finish_scene("stealth"))
	ui.button("Отойти и искать выход", ui.close)

func resolve_enemy(value: String) -> bool:
	if not is_instance_valid(enemy) or enemy.mode != ApartmentEnemy.Mode.STUNNED or state.phase != "encounter": return false
	if value == "restrained" and not InventoryManager.remove_item("rope"): return false
	if value == "lethal" and not InventoryManager.has_item("heavy"): return false
	if not state.record_outcome(value): return false
	enemy.mode = ApartmentEnemy.Mode.DEAD if value == "lethal" else ApartmentEnemy.Mode.RESTRAINED
	enemy.queue_redraw()
	state.phase = "resolved"
	ParanoiaManager.add_paranoia(15.0 if value == "lethal" else 3.0, "Исход встречи")
	checkpoint()
	ui.message("Даша", "Он больше не двигается. Я… я должна уйти." if value == "lethal" else "Он связан. Дышит. Теперь я могу уйти.")
	return true

func fail_encounter() -> void:
	ui.open("failure", "Даша не успела вырваться", "Повтор начнётся с контрольной точки перед встречей. Предметы, стресс и последствия вернутся к её состоянию.")
	ui.button("Повторить с контрольной точки", func() -> void: ui.close(); retry_checkpoint())

func finish_scene(value: String) -> void:
	if state.phase == "complete": return
	state.record_outcome(value)
	state.phase = "complete"
	SaveManager.save_game("autosave", "Глава 1 · выход из квартиры")
	var profile: Dictionary = {"version": 1, "chapter": 1, "events": state.events, "chaos_total": state.chaos_total(), "belief": state.belief, "stress": ParanoiaManager.target_paranoia, "inventory": InventoryManager.get_save_data()}
	var result_file: FileAccess = FileAccess.open("user://chapter_1_result.json", FileAccess.WRITE)
	if result_file:
		result_file.store_string(JSON.stringify(profile, "\t"))
		result_file.close()
	show_ending()

func show_ending() -> void:
	var text: String = {"stealth": "Даша незаметно вышла из квартиры, оставив незнакомца позади.", "restrained": "Даша обезвредила незнакомца и вышла из квартиры.", "lethal": "Незнакомец погиб. Даша вышла из квартиры."}.get(state.outcome, "Даша вышла из квартиры.")
	ui.open("ending", "ТЁМНАЯ КВАРТИРА / КОНЕЦ СЦЕНЫ", text + "\n\nРезультат сохранён: оставшиеся предметы, доверие дневнику и последствия поступков.\n\nПродолжение истории ещё в разработке.")
	ui.button("Вернуться к контрольной точке", func() -> void: ui.close(); retry_checkpoint())
	ui.button("Главное меню", func() -> void: ui.close(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

func _refresh_world() -> void:
	for id: String in ["front_key", "flashlight", "phone", "screwdriver", "fuse", "throwable", "rope", "heavy"]:
		world.interactables[id].visible = not state.has(id)
	world.interactables.front_key.visible = false
	world.interactables.diary.visible = false
	world.set_study_open(state.has("study_unlocked"))
	world.interactables.pills.visible = state.has("bed") and not state.has("pills")
	world.interactables.vase.visible = not state.has("vase")
	world.interactables.cupboard_key.visible = state.has("vase") and not state.has("cupboard_key")
	world.get_node("CoatFallen").visible = state.has("coat")
	if state.has("coat") and not world.interactables.has("coat_trap"):
		world.target("coat_trap", Vector2(850, 325), "Толкнуть вешалку под ноги незнакомцу")
	if not state.has("coat") and world.interactables.has("coat_trap"):
		world.interactables.coat_trap.queue_free()
		world.interactables.erase("coat_trap")
	flashlight.available = state.has("flashlight")
	if state.has("dose") and is_instance_valid(tutorial_gate): tutorial_gate.queue_free()

func can_save_chapter() -> bool:
	return not intro_active and ui != null and ui.modal_kind.is_empty() and not hidden_player

func export_chapter_save() -> Dictionary:
	return {"version": State.VERSION, "layout_revision": State.LAYOUT_REVISION, "scene": State.SCENE, "chapter": state.serialize(), "player": {"x": player.position.x, "y": player.position.y}, "inventory": InventoryManager.get_save_data(), "stress": ParanoiaManager.target_paranoia, "flashlight_on": flashlight.is_on(), "enemy": enemy.snapshot() if is_instance_valid(enemy) else {}, "checkpoint": state.checkpoint.duplicate(true)}

func import_chapter_save(data: Dictionary) -> void:
	ui.close()
	state.restore(data.chapter)
	if state.has("intro"): state.mark("opening_done")
	state.checkpoint = data.get("checkpoint", {}).duplicate(true)
	InventoryManager.load_save_data(data.inventory)
	ClueManager.reset_all_clues()
	for id: String in state.documents:
		if documents.has(id): ClueManager.register_document(id, documents[id])
	ParanoiaManager.is_decay_active = false
	ParanoiaManager.set_paranoia(float(data.stress))
	player.position = Vector2(float(data.player.x), float(data.player.y))
	player.velocity = Vector2.ZERO
	player.modulate.a = 1.0
	hidden_player = false
	sneaking = false
	flashlight.available = state.has("flashlight")
	flashlight.toggle_flashlight(bool(data.get("flashlight_on", false)) and flashlight.available, true)
	if is_instance_valid(enemy):
		enemy.free()
	if state.phase in ["encounter", "resolved"]:
		_spawn_enemy()
		enemy.restore(data.get("enemy", {}))
	if not state.has("dose") and not is_instance_valid(tutorial_gate): _build_gate()
	silhouette.visible = false
	dark_time = 0.0
	phone_glow_time = 0.0
	phone_light.enabled = false
	_refresh_world()
	player.get_node("Camera2D").reset_smoothing()
	if state.phase == "complete": show_ending.call_deferred()
	elif state.has("intro") and not state.has("dose"): ui.notify("Обучение: обыщите кровать, подберите блистер и примите одну таблетку через инвентарь.", 8)

func checkpoint() -> void:
	if not can_save_chapter(): return
	var snapshot: Dictionary = export_chapter_save()
	snapshot["checkpoint"] = {}
	state.checkpoint = snapshot
	SaveManager.auto_save("Квартира · " + str(world.ROOMS[world.room_at(player.position)][1]).to_lower())

func retry_checkpoint() -> void:
	if state.checkpoint.is_empty():
		ui.notify("Контрольная точка ещё не создана. Завершите вводное обучение.")
		return
	var snapshot: Dictionary = state.checkpoint.duplicate(true)
	snapshot["checkpoint"] = state.checkpoint.duplicate(true)
	import_chapter_save(snapshot)
	ui.notify("Контрольная точка восстановлена. Последствия неудачной попытки отменены.")
