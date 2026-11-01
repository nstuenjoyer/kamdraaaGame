class_name WindowLighting
extends Node2D

# WindowLighting — Нуарное окно в ночной дождливый город
# Включает:
# - Стекло с каплями и струйками дождя
# - Жалюзи с проекцией мягких световых полос на изометрический пол
# - Мигающую неоновую вывеску за окном (пурпурно-циановые вспышки)
# - Периодические фары проезжающих по мокрой улице машин, отбрасывающие
#   медленно смещающуюся проекцию жалюзи на пол.

@export var is_active: bool = true

# Узлы окна и освещения
var window_glass: Polygon2D
var rain_node: Node2D
var neon_light: PointLight2D
var car_light: PointLight2D
var car_timer: Timer

# Параметры неона
var _neon_timer: float = 0.0
var _neon_next_blink: float = 2.5
var _neon_is_flickering: bool = false
var _neon_flicker_count: int = 0
var _neon_color_mode: bool = false # false: Cyan/Blue, true: Magenta/Pink

# Параметры фар машин
var _is_car_passing: bool = false
var _car_progress: float = 0.0
var _car_duration: float = 3.6
const WINDOW_LIGHT_ORIGIN: Vector2 = Vector2(12.0, 6.0)
var _car_base_energy: float = 1.35

# Параметры капель дождя на стекле
var _rain_droplets: Array[Dictionary] = []
const MAX_DROPLETS: int = 14

static var _cached_neon_texture: ImageTexture = null
static var _cached_car_texture: ImageTexture = null

func _ready() -> void:
	_create_window_visuals()
	_create_blinds_visuals()
	_create_lights()
	_init_rain_droplets()
	_setup_car_timer()

func _create_window_visuals() -> void:
	# 1. Внешняя рама окна (наклон по изометрической стене NW: направление (2, -1))
	# Размер рамы: ширина 70px вдоль стены, высота 80px вверх
	var frame: Polygon2D = Polygon2D.new()
	frame.name = "WindowFrame"
	frame.color = Color(0.12, 0.14, 0.18, 1.0)
	frame.polygon = PackedVector2Array([
		Vector2(-35, 17),
		Vector2(35, -17),
		Vector2(35, -97),
		Vector2(-35, -63)
	])
	add_child(frame)

	# 2. Темное стекло с видом на ночную дождливую улицу
	window_glass = Polygon2D.new()
	window_glass.name = "WindowGlass"
	window_glass.color = Color(0.06, 0.08, 0.14, 0.95)
	window_glass.polygon = PackedVector2Array([
		Vector2(-31, 15),
		Vector2(31, -15),
		Vector2(31, -93),
		Vector2(-31, -63)
	])
	add_child(window_glass)

	# 3. Узел анимации капель дождя
	rain_node = Node2D.new()
	rain_node.name = "RainDroplets"
	rain_node.script = load("res://scripts/window_rain_drawer.gd")
	add_child(rain_node)

func _create_blinds_visuals() -> void:
	# Жалюзи (горизонтальные ламели)
	var blinds_root: Node2D = Node2D.new()
	blinds_root.name = "Blinds"
	add_child(blinds_root)

	var num_slats: int = 8
	for i in range(num_slats):
		var t: float = float(i) / float(num_slats)
		var y_offset: float = lerpf(12.0, -78.0, t)
		var p1: Vector2 = Vector2(-30, y_offset)
		var p2: Vector2 = Vector2(30, y_offset - 30.0)

		# Ламель жалюзи
		var slat: Line2D = Line2D.new()
		slat.points = PackedVector2Array([p1, p2])
		slat.width = 2.4
		slat.default_color = Color(0.18, 0.22, 0.28, 0.92)
		blinds_root.add_child(slat)

	# Vertical slats are visual only. Ground-plane occluders would create
	# wedges from every room light; the window texture projects their pattern.

func _create_lights() -> void:
	# 1. Неоновая вывеска снаружи
	neon_light = PointLight2D.new()
	neon_light.name = "NeonSignLight"
	neon_light.color = Color(0.15, 0.85, 1.0, 1.0)
	neon_light.energy = 0.8
	neon_light.texture = _get_or_create_projected_texture(false)
	neon_light.texture_scale = 1.0
	neon_light.position = WINDOW_LIGHT_ORIGIN
	neon_light.shadow_enabled = true
	neon_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	neon_light.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(neon_light)

	# 2. Фары проезжающей машины
	car_light = PointLight2D.new()
	car_light.name = "CarHeadlightsLight"
	car_light.color = Color(1.0, 0.96, 0.85, 1.0)
	car_light.energy = 0.0
	car_light.enabled = false
	car_light.texture = _get_or_create_projected_texture(true)
	car_light.texture_scale = 1.25
	car_light.position = WINDOW_LIGHT_ORIGIN
	car_light.shadow_enabled = true
	car_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	car_light.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(car_light)

func _setup_car_timer() -> void:
	car_timer = Timer.new()
	car_timer.name = "CarTimer"
	car_timer.one_shot = false
	car_timer.wait_time = randf_range(16.0, 24.0)
	car_timer.timeout.connect(_trigger_car_pass)
	add_child(car_timer)
	car_timer.start()

func _init_rain_droplets() -> void:
	_rain_droplets.clear()
	for i in range(MAX_DROPLETS):
		_rain_droplets.append({
			"u": randf(), # вдоль стены (-30..+30)
			"v": randf(), # по высоте
			"speed": randf_range(0.15, 0.45),
			"length": randf_range(4.0, 9.0),
			"alpha": randf_range(0.35, 0.75)
		})

func _process(delta: float) -> void:
	if not is_active:
		return

	_update_neon_sign(delta)
	_update_car_pass(delta)
	_update_rain(delta)

func _update_neon_sign(delta: float) -> void:
	if not neon_light:
		return

	_neon_timer += delta
	if not _neon_is_flickering and _neon_timer >= _neon_next_blink:
		_neon_timer = 0.0
		_neon_next_blink = randf_range(2.8, 6.5)
		_neon_is_flickering = true
		_neon_flicker_count = randi_range(2, 5)
		# Сменяем цвет вывески: Неоновый циан ➔ Неоновый пурпур
		_neon_color_mode = not _neon_color_mode
		if _neon_color_mode:
			neon_light.color = Color(1.0, 0.22, 0.65, 1.0) # Electric Magenta
		else:
			neon_light.color = Color(0.12, 0.85, 1.0, 1.0) # Cyber Cyan

	if _neon_is_flickering:
		# Быстрое дребезжание контактов старой неоновой лампы
		var micro_flicker: float = randf()
		if micro_flicker < 0.35:
			neon_light.energy = 0.15
		elif micro_flicker < 0.7:
			neon_light.energy = 1.15
		else:
			neon_light.energy = 0.75

		_neon_flicker_count -= 1
		if _neon_flicker_count <= 0:
			_neon_is_flickering = false
			neon_light.energy = 0.85
	else:
		# Спокойное мягкое мерцание газа в трубке
		var t_sec: float = Time.get_ticks_msec() / 1000.0
		neon_light.energy = 0.8 + sin(t_sec * 12.0) * 0.06

func _trigger_car_pass() -> void:
	if _is_car_passing:
		return

	_is_car_passing = true
	_car_progress = 0.0
	_car_duration = randf_range(3.2, 4.4)
	if car_light:
		car_light.enabled = true
		car_light.energy = 0.0

	# Звук проезжающей машины с шелестом шин по мокрому асфальту
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_car_pass"):
		sound_mgr.play_car_pass()

	car_timer.wait_time = randf_range(18.0, 32.0)
	car_timer.start()

func _update_car_pass(delta: float) -> void:
	if not _is_car_passing or not car_light:
		return

	_car_progress += delta / _car_duration
	if _car_progress >= 1.0:
		_is_car_passing = false
		car_light.enabled = false
		car_light.energy = 0.0
		return

	# Keep the projected source on the room side of the wall; slide along it.
	car_light.position = WINDOW_LIGHT_ORIGIN + Vector2(2.0, -1.0) * lerpf(-8.0, 8.0, _car_progress)
	car_light.rotation = lerpf(-0.06, 0.06, _car_progress)

	# Колоколообразная кривая яркости фар (нарастание ➔ пик ➔ затухание вдали)
	var bell: float = sin(_car_progress * PI)
	car_light.energy = _car_base_energy * (bell * bell)

func _update_rain(delta: float) -> void:
	for drop in _rain_droplets:
		drop["v"] += drop["speed"] * delta
		if drop["v"] > 1.0:
			drop["v"] = 0.0
			drop["u"] = randf()
			drop["speed"] = randf_range(0.18, 0.5)

	if rain_node and rain_node.has_method("set_droplets"):
		rain_node.set_droplets(_rain_droplets)

# ========================================================
# Процедурные текстуры
# ========================================================

func _get_or_create_projected_texture(for_car: bool) -> ImageTexture:
	var cached: ImageTexture = _cached_car_texture if for_car else _cached_neon_texture
	if cached:
		return cached

	var size: int = 512
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var point: Vector2 = Vector2(x, y) - Vector2(size, size) * 0.5
			# Inverse isometric basis: along the NW wall (1, -0.5), into room (1, 0.5).
			var along_wall: float = (point.x - 2.0 * point.y) * 0.5
			var depth: float = (point.x + 2.0 * point.y) * 0.5
			if depth < 0.0 or depth > 230.0:
				continue
			var half_width: float = lerpf(29.0, 43.0, depth / 230.0)
			var aperture: float = 1.0 - smoothstep(half_width - 5.0, half_width, absf(along_wall))
			var falloff: float = smoothstep(0.0, 10.0, depth) * pow(1.0 - depth / 230.0, 1.2)
			var bands: float = smoothstep(0.18, 0.42, absf(sin((depth + 8.0) * PI / 27.0)))
			var alpha: float = aperture * falloff * (0.08 + bands * 0.92)
			if for_car:
				alpha *= 0.6 + 0.4 * absf(sin(along_wall * 0.06))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	var texture: ImageTexture = ImageTexture.create_from_image(img)
	if for_car:
		_cached_car_texture = texture
	else:
		_cached_neon_texture = texture
	return texture
