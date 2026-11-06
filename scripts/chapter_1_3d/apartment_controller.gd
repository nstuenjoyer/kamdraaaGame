extends Node

const Layout: GDScript = preload("res://scripts/chapter_1_3d/layout.gd")
const World: GDScript = preload("res://scripts/chapter_1_3d/apartment_world.gd")
const Player: GDScript = preload("res://scripts/chapter_1_3d/player.gd")
const Screen: GDScript = preload("res://scripts/chapter_1_3d/apartment_ui.gd")
const Enemy: GDScript = preload("res://scripts/chapter_1_3d/enemy.gd")
const Story: GDScript = preload("res://scripts/chapter_1/apartment_story.gd")
const SAVE_DIR: String = "user://saves/chapter_1_3d/"
const SCENE: String = "res://scenes/chapter_1_3d/apartment.tscn"
var state: ApartmentState = ApartmentState.new()
var world: ApartmentWorld3D
var player: ApartmentPlayer3D
var camera: Camera3D
var viewport_3d: SubViewport
var ui: ApartmentUI
var enemy: ApartmentEnemy3D
var story: RefCounted
var documents: Dictionary = {}
var selected: String = ""
var hidden_player: bool = false
var sneaking: bool = false
var intro_active: bool = false
var intro_skip_requested: bool = false
var dither_enabled: bool = true
var presentation: ShaderMaterial
var room_id: String = ""
var camera_anchor: Vector3
var camera_target: Vector3
var dark_time: float = 0.0
var blind_cooldown: float = 0.0
var blind_exposure: float = 0.0
var checkpoint_data: Dictionary = {}
var navigation_ready: bool = false
var stair_camera: bool = false
var crt_enabled: bool = false
var vertex_snap_enabled: bool = false
var affine_enabled: bool = false
var listener: AudioListener3D
var audio_timer: float = 0.0

func _ready() -> void:
	SoundManager.stop_bg_music()
	SoundManager.stop_heartbeat()
	ParanoiaManager.is_active = true
	ParanoiaManager.is_decay_active = false
	InventoryManager.reset_inventory()
	ClueManager.reset_all_clues()
	ParanoiaManager.set_paranoia(100.0)
	documents = JSON.parse_string(FileAccess.get_file_as_string("res://resources/chapter_1/documents.json"))
	# Geography belongs to this layout; original 2D documents remain untouched.
	for id: String in documents:
		documents[id].text = str(documents[id].text).replace("за галереей, рядом с постирочной", "на втором этаже, за галереей").replace("в рабочем ящике постирочной", "в рабочем ящике постирочной на первом этаже")
	_setup_viewport()
	world = World.new()
	viewport_3d.add_child(world)
	world.build()
	player = Player.new()
	world.add_child(player)
	player.setup(self)
	player.position = Layout.center("bedroom") + Vector3(1.3, 0.05, 0.7)
	camera = Camera3D.new()
	viewport_3d.add_child(camera)
	camera.fov = 50
	camera.near = 0.1
	camera.far = 85
	camera.current = true
	story = Story.new()
	story.setup(self)
	ui = Screen.new()
	add_child(ui)
	ui.setup(self)
	SaveManager.toast_requested.connect(ui.notify)
	InventoryManager.item_used.connect(_on_item_used)
	state.mark("intro")
	state.mark("opening_done")
	_refresh_world()
	_load_graphics()
	_update_camera(true)
	ui.message("Даша · второй этаж", "Накануне вечером погас свет. Часы разошлись, а последние часы словно выпали из памяти. Под одеялом у кровати должен быть блистер. Нужно осмотреть кровать, взять таблетки и принять одну через сумку.")
	_bake_navigation.call_deferred()

func _setup_viewport() -> void:
	viewport_3d = SubViewport.new()
	viewport_3d.name = "PSXWorld"
	viewport_3d.size = Vector2i(640, 360)
	viewport_3d.own_world_3d = true
	viewport_3d.audio_listener_enable_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_3d.positional_shadow_atlas_size = 2048
	add_child(viewport_3d)
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101722")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("8a9fb3")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.fog_enabled = true
	settings.fog_light_color = Color("4d6475")
	settings.fog_density = 0.002
	settings.fog_sky_affect = 0.1
	environment.environment = settings
	viewport_3d.add_child(environment)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var image: TextureRect = TextureRect.new()
	image.name = "PSXPresentation"
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = viewport_3d.get_texture()
	presentation = ShaderMaterial.new()
	presentation.shader = preload("res://shaders/psx_present.gdshader")
	image.material = presentation
	layer.add_child(image)
	listener = AudioListener3D.new()
	viewport_3d.add_child(listener)
	listener.make_current()

func _bake_navigation() -> void:
	# Let Node3D collision/link transforms reach their servers before parsing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	NavigationServer3D.map_set_link_connection_radius(world.get_world_3d().navigation_map, 0.75)
	world.add_to_group("apartment_3d_nav")
	world.navigation.navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	world.navigation.navigation_mesh.geometry_source_group_name = "apartment_3d_nav"
	world.navigation.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	NavigationServer3D.map_force_update(world.get_world_3d().navigation_map)
	navigation_ready = true
	SaveManager.apply_pending_save_if_any(self)

func is_blocked() -> bool:
	return get_tree().paused or ui == null or not ui.modal_kind.is_empty() or intro_active

func current_goal() -> String:
	if not state.has("bed"): return "Осмотрите кровать · спальня, второй этаж"
	if not state.has("pills"): return "Подберите блистер у кровати"
	if not state.has("dose"): return "Откройте сумку и примите одну таблетку"
	if state.phase == "complete": return "Глава завершена"
	if state.phase == "encounter": return "Скройтесь и вернитесь к выходу либо обезвредьте незнакомца"
	if state.phase == "resolved": return "Вернитесь к входной двери · первый этаж"
	return story.goal()

func goal_details() -> String:
	if not state.has("dose"): return "В блистере две таблетки. Примите одну через сумку. Свет не снижает накопленный стресс."
	return str(story.details()).replace("дверь в конце гостиной, за поперечной галереей", "дверь на втором этаже, за галереей").replace("рядом с постирочной", "на втором этаже").replace("в задний коридор", "в зимний сад")

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	_update_camera(false, delta)
	world.update_visibility(player.global_position, camera, room_id, delta)
	listener.position = player.position + Vector3.UP * 1.5
	audio_timer -= delta
	if audio_timer <= 0:
		audio_timer = 0.25
		world.update_audio(listener.position)
	presentation.set_shader_parameter("crt_enabled", crt_enabled)
	if is_blocked(): return
	sneaking = player.movement_mode == "sneak"
	blind_cooldown = maxf(0, blind_cooldown - delta)
	if state.has("phone_charging") and not state.has("phone_ready"):
		state.charge = minf(20, state.charge + delta)
		if state.charge >= 20:
			state.mark("phone_ready")
			ui.notify("Телефон зарядился. Вернитесь к тумбочке в спальне.")
	if state.has("power") or player.torch.visible or Layout.room_at(player.position) == "bedroom":
		dark_time = 0
	else:
		dark_time += delta
		if dark_time > 12 and state.has("dose"):
			ParanoiaManager.add_paranoia(delta * 0.12 * (1 + state.belief / 100), "Темнота")
	_update_target()
	if is_instance_valid(enemy) and state.phase == "encounter" and _aimed_at_enemy(5.0, 0.92) and player.torch.visible:
		blind_exposure += delta
		if blind_exposure > 1.5: blind_enemy()
	else: blind_exposure = 0

func _update_camera(immediate: bool = false, delta: float = 0.0) -> void:
	var on_stair: bool = absf(player.position.x) > 12.2
	if on_stair:
		var stair_center: Vector3 = Vector3(-14, 2.1, 0.5) if player.position.x < 0 else Vector3(14, 2.1, 6.5)
		camera.position = stair_center + Vector3(-8 if player.position.x < 0 else 8, 6, 7)
		camera.look_at(stair_center + Vector3.UP)
		stair_camera = true
		return
	if stair_camera:
		immediate = true
		stair_camera = false
	var next_room: String = Layout.room_at(player.position)
	if not immediate and next_room != room_id and Layout.ROOMS.has(room_id):
		var rect: Rect2 = Layout.ROOMS[next_room][1]
		if not rect.grow(-0.35).has_point(Vector2(player.position.x, player.position.z)): next_room = room_id
	if immediate or next_room != room_id:
		room_id = next_room
		var center: Vector3 = Layout.center(room_id)
		camera_target = center + Layout.CAMERAS[room_id][1]
		camera_anchor = center + Layout.CAMERAS[room_id][0]
		camera.position = camera_anchor
		camera.look_at(camera_target)
	var offset: Vector3 = player.position - Layout.center(room_id)
	offset.y = 0
	offset = offset.limit_length(1.1) * 0.35
	if not immediate: camera.position = camera.position.lerp(camera_anchor + offset, 1.0 - exp(-delta * 3))

func mouse_world() -> Vector3:
	var screen: Vector2 = get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size * Vector2(viewport_3d.size)
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	var plane: Plane = Plane(Vector3.UP, player.position.y)
	var point: Variant = plane.intersects_ray(origin, direction)
	return point as Vector3 if point != null else player.position + Vector3.FORWARD

func get_global_mouse_position() -> Vector3:
	return mouse_world()

func _target_available(id: String) -> bool:
	if id == "charger": return state.has("phone")
	if id == "pills": return state.has("bed") and not state.has("pills")
	if id == "cupboard_key": return state.has("vase") and not state.has("cupboard_key")
	if id == "coat_trap": return state.has("coat") and not state.has("coat_trap")
	if id in ["flashlight", "phone", "screwdriver", "fuse", "throwable", "rope", "heavy", "vase"]: return not state.has(id)
	if id in ["study_door", "study_door_side"]: return not state.has("study_unlocked")
	return true

func _update_target() -> void:
	selected = ""
	var nearest: float = 1.6
	for id: String in world.interactables:
		var object: Node3D = world.interactables[id]
		if not _target_available(id): continue
		var distance: float = target_distance(player.global_position, object.global_position)
		var point: Vector3 = object.global_position + Vector3.UP * 0.12
		if id in ["study_door", "study_door_side"]: point += point.direction_to(player.position + Vector3.UP * 1.5) * 0.32
		if distance < nearest and world.clear_line(player.position + Vector3.UP * 1.5, point):
			nearest = distance
			selected = id
	if hidden_player:
		ui.prompt.text = "[%s] Выйти из укрытия" % ui.key("interact")
	elif is_instance_valid(enemy) and enemy.mode == Enemy.Mode.STUNNED and player.position.distance_to(enemy.position) < 1.75:
		selected = "enemy"
		ui.prompt.text = "[%s] Оглушён · действия" % ui.key("interact")
	else:
		ui.prompt.text = "[%s] %s" % [ui.key("interact"), world.interactables[selected].get_meta("title")] if not selected.is_empty() else ""

func target_distance(foot: Vector3, point: Vector3) -> float:
	if absf(point.y - foot.y) > 1.9: return INF
	return Vector2(point.x - foot.x, point.z - foot.z).length()

func _unhandled_input(event: InputEvent) -> void:
	if is_blocked() or event.is_echo(): return
	if event.is_action_pressed("interact"):
		if hidden_player:
			hidden_player = false
			player.set_control_locked(false)
		else: interact(selected)
	elif event.is_action_pressed("toggle_flashlight") and state.has("flashlight"): player.torch.visible = not player.torch.visible
	elif event.is_action_pressed("quick_save"): save_slot("slot_1")
	elif event.is_action_pressed("quick_load"): load_slot("slot_1")
	elif event.is_action_pressed("use_tool"): use_pepper()
	elif event.is_action_pressed("blind"): blind_enemy()
	elif event.is_action_pressed("throw_item"): throw_vase(mouse_world())

func interact(id: String) -> void:
	if is_blocked() or id.is_empty() or (id != "enemy" and not _target_available(id)): return
	if id != selected: return
	if story.interact(id): return
	match id:
		"bed":
			state.mark("bed")
			ui.notify("Под одеялом блистер с двумя таблетками. Подберите его у кровати.")
		"pills": _pickup(id, "Седативное", "Две таблетки. Одна доза снижает стресс на 40.", "plastic", 2, true)
		"flashlight":
			_pickup(id, "Фонарик", "Направляйте мышью. Свет не снижает накопленную тревогу.", "metal")
			player.torch.visible = true
		"phone": _pickup(id, "Мобильный телефон", "Разряжен. Кабель на тумбочке в спальне.", "plastic")
		"screwdriver": _pickup(id, "Отвёртка", "Для засова и щитка.", "metal")
		"fuse": _pickup(id, "Предохранитель", "Для щитка в кладовой.", "metal")
		"rope": _pickup(id, "Бельевой шнур", "Можно связать оглушённого незнакомца.", "plastic")
		"heavy": _pickup(id, "Чугунная сковорода", "Тяжёлый удар требует отдельного подтверждения.", "metal")
		"throwable": _pickup(id, "Целая ваза", "Для отвлечения во время встречи.", "glass")
		"vase":
			state.mark("vase")
			ui.notify("Под осколками ключ. Теперь его можно подобрать.")
		"cupboard_key": _pickup(id, "Ключ от шкафа", "Найден под осколками.", "metal")
		"cupboard":
			if state.has("cupboard"): ui.notify("В шкафу больше ничего нет.")
			elif InventoryManager.has_item("cupboard_key"):
				InventoryManager.remove_item("cupboard_key")
				state.mark("cupboard")
				state.mark("pepper")
				InventoryManager.add_item("pepper", "Перцовый баллончик", 1, "", "Один заряд на близкой дистанции.")
			else: ui.notify("Нужен маленький ключ. Проверьте осколки в гостиной.")
		"bedside", "bathroom", "bath_note", "hall_mirror": read_document(id)
		"fusebox": _repair_power()
		"charger": _charge_phone()
		"exit": attempt_exit()
		"hide_sofa", "hide_bath", "hide_wardrobe": enter_hiding()
		"enemy": enemy_choices()
		"coat_trap":
			if is_instance_valid(enemy) and player.position.distance_to(enemy.position) < 2.3:
				state.mark("coat_trap")
				enemy.stun(7)
				ui.notify("Вешалка сбила его с ног.")
		"garden_note": ui.message("Следы дождя", "На внутренней стороне стекла отпечатки пальцев. Одно кресло развёрнуто к окнам чужого дома. Отсюда хорошо видно служебную лестницу.")
		"guest_note": ui.message("Чужой чемодан", "Бирка оторвана. В складке ткани застряла такая же тёмная нить, как на крючке в прихожей. Я готовила эту комнату к чьему-то приезду.")
	_refresh_world()

func _pickup(id: String, title: String, description: String, kind: String, amount: int = 1, usable: bool = false) -> void:
	if not state.mark(id): return
	InventoryManager.add_item(id, title, amount, "", description, usable)
	SoundManager.play_material_interact(kind)
	_refresh_world()

func _on_item_used(id: String, success: bool) -> void:
	if id == "pills" and success and state.mark("dose"):
		ui.notify("Одна таблетка осталась. Пассивного снижения тревоги нет.")
		checkpoint.call_deferred()

func read_document(id: String) -> void:
	if id not in state.documents:
		state.documents.append(id)
		ClueManager.register_document(id, documents[id])
		if id in ["bathroom", "hall_mirror"]: ParanoiaManager.add_paranoia(4, "Надпись")
	ui.document(id)

func choose_diary(value: String) -> void:
	if state.choose(value):
		ParanoiaManager.add_paranoia(8 if value == "trust" else 2, "Решение")
		checkpoint()

func _repair_power() -> void:
	if state.has("power"): ui.notify("Электричество работает.")
	elif not InventoryManager.has_item("screwdriver") or not InventoryManager.has_item("fuse"): ui.message("Щиток", "Нужны отвёртка из постирочной и предохранитель из кухни. Ремонт необязателен для выхода.")
	else: story.power_panel()

func _charge_phone() -> void:
	if not state.has("phone"): ui.notify("Сначала возьмите телефон.")
	elif not state.has("power"): ui.notify("Сначала восстановите электричество.")
	elif state.has("phone_ready"):
		ui.open("phone", "Телефон · связи нет")
		ui.button("Сообщения", func() -> void: read_document("messages"))
		ui.button("Заметка", func() -> void: read_document("phone_note"))
		ui.button("Закрыть", ui.close)
	elif state.mark("phone_charging"): ui.notify("Зарядка: 20 секунд игрового времени.")
	else: ui.notify("Заряжается · %d%%" % roundi(state.charge * 5))

func _refresh_world() -> void:
	for id: String in world.interactables:
		world.interactables[id].visible = _target_available(id)
	world.set_study_open(state.has("study_unlocked"))
	for lamp: OmniLight3D in world.lamps: lamp.light_energy = 1.1 if state.has("power") else 0

func attempt_exit() -> void:
	if not state.has("dose"):
		ui.message("Даша", "Перед выходом нужно прийти в себя. Таблетки у кровати на втором этаже.")
		return
	if story.exit_blocker(): return
	if not state.has("front_key"): return
	if state.diary_choice.is_empty():
		ui.notify("Нужно прочитать дневник из дивана и принять решение.")
		return
	if state.phase == "encounter":
		if can_escape(): finish_scene("stealth")
		else: ui.notify("Он видит выход. Скройтесь или отвлеките его.")
	elif state.phase == "resolved": finish_scene(state.outcome)
	elif not state.has("coat"):
		checkpoint()
		ui.begin_qte()
	else:
		ui.open("confirm_exit", "Ключ в замке", "Я могу ещё вернуться к поиску.")
		ui.button("Повернуть ключ", func() -> void: ui.close(); begin_encounter())
		ui.button("Отойти", ui.close)

func finish_coat() -> void:
	state.mark("coat")
	state.phase = "coat_done"
	_refresh_world()
	ui.message("Пальто и вешалка", "Это просто ткань. Крючок выскочил. Вешалка осталась у двери: её можно толкнуть под ноги тому, кто приблизится.", checkpoint)

func _spawn_enemy() -> void:
	if is_instance_valid(enemy): enemy.free()
	enemy = Enemy.new()
	world.add_child(enemy)
	enemy.setup(self)
	enemy.position = Layout.center("hall") + Vector3(-1, 0.05, -4)

func begin_encounter() -> void:
	if state.phase == "encounter" or not state.has("coat"): return
	checkpoint()
	state.phase = "encounter"
	_spawn_enemy()
	ParanoiaManager.add_paranoia(15, "Незнакомец")
	ui.notify("В квартиру вошёл незнакомец. Отойдите от двери; лестницы и кольцевые проходы позволяют скрыться.")

func can_escape() -> bool:
	return is_instance_valid(enemy) and (enemy.mode in [Enemy.Mode.STUNNED, Enemy.Mode.RESTRAINED, Enemy.Mode.DEAD] or (enemy.position.distance_to(player.position) > 3.5 and not enemy.sees_player()))

func _aimed_at_enemy(distance: float, cone: float) -> bool:
	if not is_instance_valid(enemy): return false
	var offset: Vector3 = enemy.position - player.position
	return offset.length() < distance and (-player.torch.global_basis.z).dot(offset.normalized()) > cone and world.clear_line(player.torch.global_position, enemy.position + Vector3.UP)

func use_pepper() -> bool:
	if state.phase != "encounter" or not InventoryManager.has_item("pepper") or not _aimed_at_enemy(2.7, 0.55): return false
	InventoryManager.remove_item("pepper")
	enemy.stun(12)
	ui.notify("Перец попал в лицо. Заряд израсходован.")
	return true

func blind_enemy() -> bool:
	if state.phase != "encounter" or not player.torch.visible or blind_cooldown > 0 or not _aimed_at_enemy(5, 0.86): return false
	enemy.stun(5)
	blind_cooldown = 9
	blind_exposure = 0
	return true

func throw_vase(point: Vector3) -> bool:
	if state.phase != "encounter" or not InventoryManager.has_item("throwable"): return false
	if point.distance_to(player.position) > 8 or not world.clear_line(player.position + Vector3.UP, point + Vector3.UP * 0.1): return false
	var ground: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point - Vector3.UP * 0.5, 1)
	if world.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(): return false
	InventoryManager.remove_item("throwable")
	SoundManager.play_material_interact("glass")
	enemy.hear(point)
	return true

func enter_hiding() -> void:
	if state.phase != "encounter" or player.torch.visible or enemy.sees_player():
		ui.notify("Для укрытия выключите фонарик и разорвите линию видимости.")
		return
	hidden_player = true
	player.set_control_locked(true)

func enemy_choices() -> void:
	if not is_instance_valid(enemy) or enemy.mode != Enemy.Mode.STUNNED: return
	ui.open("enemy_choice", "Он оглушён", "Можно уйти, связать его шнуром или применить тяжёлый предмет.")
	if InventoryManager.has_item("rope"): ui.button("Связать", func() -> void: ui.close(); resolve_enemy("restrained"))
	if InventoryManager.has_item("heavy"):
		ui.button("Ударить сковородой", func() -> void:
			ui.open("lethal_confirm", "Необратимое решение", "Удар по голове может убить. Продолжить?")
			ui.button("Нанести смертельный удар", func() -> void: ui.close(); resolve_enemy("lethal"))
			ui.button("Отойти", ui.close))
	ui.button("Отойти", ui.close)

func resolve_enemy(value: String) -> bool:
	if state.phase != "encounter" or not is_instance_valid(enemy) or enemy.mode != Enemy.Mode.STUNNED: return false
	if player.position.distance_to(enemy.position) > 1.75 or not world.clear_line(player.position + Vector3.UP, enemy.position + Vector3.UP): return false
	if value not in ["restrained", "lethal"]: return false
	if value == "restrained" and not InventoryManager.remove_item("rope"): return false
	if value == "lethal" and not InventoryManager.has_item("heavy"): return false
	if not state.record_outcome(value): return false
	enemy.mode = Enemy.Mode.DEAD if value == "lethal" else Enemy.Mode.RESTRAINED
	state.phase = "resolved"
	checkpoint()
	return true

func fail_encounter() -> void:
	ui.open("failure", "Даша не успела вырваться", "Повтор восстановит ресурсы и последствия до встречи.")
	ui.button("Повторить", func() -> void: ui.close(); retry_checkpoint())

func finish_scene(value: String) -> void:
	if state.phase == "complete": return
	state.record_outcome(value)
	state.phase = "complete"
	save_slot("autosave")
	var result: FileAccess = FileAccess.open("user://chapter_1_3d_result.json", FileAccess.WRITE)
	if result: result.store_string(JSON.stringify({"version": 1, "events": state.events, "chaos_total": state.chaos_total(), "belief": state.belief, "stress": ParanoiaManager.target_paranoia, "inventory": InventoryManager.get_save_data()}))
	ui.open("ending", "Тёмная квартира · конец главы", {"stealth": "Даша незаметно вышла из квартиры.", "restrained": "Незнакомец связан. Даша вышла из квартиры.", "lethal": "Незнакомец погиб. Даша вышла из квартиры."}.get(state.outcome, ""))
	ui.button("Главное меню", func() -> void: ui.close(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

func set_dither(value: bool) -> void:
	dither_enabled = value
	presentation.set_shader_parameter("dither_strength", 0.18 if value else 0.0)
	_save_graphics()

func set_retro_options(crt: bool, snap: bool, affine: bool) -> void:
	crt_enabled = crt
	vertex_snap_enabled = snap
	affine_enabled = affine
	_apply_retro_materials(world)
	_save_graphics()

func _apply_retro_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: ShaderMaterial = (node as MeshInstance3D).material_override as ShaderMaterial
		if mat != null and mat.shader == World.SURFACE:
			mat.set_shader_parameter("vertex_snap", 0.25 if vertex_snap_enabled else 0.0)
			mat.set_shader_parameter("affine_strength", 0.35 if affine_enabled else 0.0)
	# Meshy's face and source materials deliberately receive neither distortion.
	for child: Node in node.get_children(): _apply_retro_materials(child)

func _load_graphics() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://psx_3d.cfg") != OK: return
	dither_enabled = bool(config.get_value("graphics", "dither", true))
	crt_enabled = bool(config.get_value("graphics", "crt", false))
	vertex_snap_enabled = bool(config.get_value("graphics", "snap", false))
	affine_enabled = bool(config.get_value("graphics", "affine", false))
	presentation.set_shader_parameter("dither_strength", 0.18 if dither_enabled else 0.0)
	_apply_retro_materials(world)

func _save_graphics() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("graphics", "dither", dither_enabled)
	config.set_value("graphics", "crt", crt_enabled)
	config.set_value("graphics", "snap", vertex_snap_enabled)
	config.set_value("graphics", "affine", affine_enabled)
	config.save("user://psx_3d.cfg")

func skip_intro() -> void:
	intro_skip_requested = true

func _intro_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func can_save_chapter() -> bool:
	return not is_blocked() and not hidden_player

func export_chapter_save() -> Dictionary:
	return {"version": 4, "layout_revision": 1, "scene": SCENE, "chapter": state.serialize(), "player": {"x": player.position.x, "y": player.position.y, "z": player.position.z, "yaw": player.visual.rotation.y}, "inventory": InventoryManager.get_save_data(), "stress": ParanoiaManager.target_paranoia, "flashlight_on": player.torch.visible, "enemy": enemy.snapshot() if is_instance_valid(enemy) else {}, "checkpoint": checkpoint_data.duplicate(true)}

func import_chapter_save(data: Dictionary) -> void:
	ui.close()
	state.restore(data.chapter)
	checkpoint_data = data.checkpoint.duplicate(true)
	InventoryManager.load_save_data(data.inventory)
	ClueManager.reset_all_clues()
	for id: String in state.documents: ClueManager.register_document(id, documents[id])
	ParanoiaManager.set_paranoia(float(data.stress))
	player.position = Vector3(data.player.x, data.player.y, data.player.z)
	player.visual.rotation.y = float(data.player.yaw)
	player.velocity = Vector3.ZERO
	player.torch.visible = bool(data.flashlight_on) and state.has("flashlight")
	hidden_player = false
	dark_time = 0
	blind_cooldown = 0
	blind_exposure = 0
	if is_instance_valid(enemy): enemy.free()
	if state.phase in ["encounter", "resolved"]:
		_spawn_enemy()
		enemy.restore(data.enemy)
	_refresh_world()
	_update_camera(true)

func checkpoint() -> void:
	if not can_save_chapter(): return
	_refresh_world()
	checkpoint_data = {}
	checkpoint_data = export_chapter_save()
	checkpoint_data.checkpoint = {}
	save_slot("autosave")

func retry_checkpoint() -> void:
	if checkpoint_data.is_empty(): return
	var snapshot: Dictionary = checkpoint_data.duplicate(true)
	snapshot.checkpoint = checkpoint_data.duplicate(true)
	import_chapter_save(snapshot)

func save_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"

func save_slot(slot: String) -> bool:
	if slot not in ["slot_1", "slot_2", "slot_3", "autosave"] or not can_save_chapter(): return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path: String = save_path(slot)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	var data: Dictionary = export_chapter_save()
	data["slot_title"] = "Автосохранение" if slot == "autosave" else slot.replace("slot_", "Слот ")
	data["timestamp"] = Time.get_datetime_string_from_system().replace("T", " ")
	data["location"] = str(Layout.ROOMS[Layout.room_at(player.position)][2]) + " · 3D"
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var status: Error = DirAccess.rename_absolute(path + ".tmp", path)
	ui.notify("Сохранено · " + slot if status == OK else "Не удалось записать сохранение")
	return status == OK

func load_slot(slot: String) -> bool:
	if slot not in ["slot_1", "slot_2", "slot_3", "autosave"] or not FileAccess.file_exists(save_path(slot)): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if not preload("res://scripts/chapter_1_3d/save_schema.gd").valid(data):
		ui.notify("Сохранение повреждено или относится к другой версии")
		return false
	var point: Vector3 = Vector3(data.player.x, data.player.y, data.player.z)
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 1.65
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3(0, 0.88, 0)
	query.collision_mask = 1 | 8
	var surface: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ground: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point - Vector3.UP * 0.8, 1 | 16)
	if not surface.intersect_shape(query).is_empty() or surface.intersect_ray(ground).is_empty():
		ui.notify("Позиция в сохранении недоступна в текущей локации")
		return false
	import_chapter_save(data)
	return true

func allows_heartbeat_audio() -> bool:
	return false
