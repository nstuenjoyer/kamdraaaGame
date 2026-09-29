class_name WindowLighting
extends Node2D

# WindowLighting — Нуарное окно в ночной дождливый город
# Включает:
# - Стекло с каплями и струйками дождя
# - Жалюзи (Venetian blinds) с окклюдерами теней
# - Мигающую неоновую вывеску за окном (пурпурно-циановые вспышки)
# - Периодические фары проезжающих по мокрой улице машин, отбрасывающие
#   медленно ползущие тени от жалюзи по всей комнате.

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
var _car_start_pos: Vector2 = Vector2(-180, -90)
var _car_end_pos: Vector2 = Vector2(80, -20)
var _car_base_energy: float = 1.35

# Параметры капель дождя на стекле
var _rain_droplets: Array[Dictionary] = []
const MAX_DROPLETS: int = 14

static var _cached_radial_texture: ImageTexture = null
static var _cached_car_texture: ImageTexture = null

func _ready() -> void:
	_create_window_visuals()
	_create_blinds_and_occluders()
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

func _create_blinds_and_occluders() -> void:
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

		# Теневой окклюдер для каждой ламели, чтобы свет снаружи отбрасывал полосатые тени!
		var occluder: LightOccluder2D = LightOccluder2D.new()
		var poly: OccluderPolygon2D = OccluderPolygon2D.new()
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		# Тонкий окклюдер вдоль ламели
		poly.polygon = PackedVector2Array([
			p1 + Vector2(0, -1.0),
			p2 + Vector2(0, -1.0),
			p2 + Vector2(0, 1.0),
			p1 + Vector2(0, 1.0)
		])
		occluder.occluder = poly
		blinds_root.add_child(occluder)

func _create_lights() -> void:
	# 1. Неоновая вывеска снаружи
	neon_light = PointLight2D.new()
	neon_light.name = "NeonSignLight"
	neon_light.color = Color(0.15, 0.85, 1.0, 1.0)
	neon_light.energy = 0.8
	neon_light.texture = _get_or_create_radial_texture()
	neon_light.texture_scale = 1.9
	neon_light.position = Vector2(-25, -45)
	neon_light.shadow_enabled = true
	neon_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	neon_light.shadow_color = Color(0.04, 0.05, 0.08, 0.82)
	add_child(neon_light)

	# 2. Фары проезжающей машины
	car_light = PointLight2D.new()
	car_light.name = "CarHeadlightsLight"
	car_light.color = Color(1.0, 0.96, 0.85, 1.0)
	car_light.energy = 0.0
	car_light.enabled = false
	car_light.texture = _get_or_create_car_headlight_texture()
	car_light.texture_scale = 2.4
	car_light.shadow_enabled = true
	car_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	car_light.shadow_color = Color(0.03, 0.04, 0.07, 0.85)
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

	# Плавное движение фар по траектории за окном
	var pos: Vector2 = _car_start_pos.lerp(_car_end_pos, _car_progress)
	car_light.position = pos

	# Угол луча фар разворачивается по мере проезда машины
	var sweep_angle_rad: float = lerpf(deg_to_rad(35.0), deg_to_rad(75.0), _car_progress)
	car_light.rotation = sweep_angle_rad

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

func _get_or_create_radial_texture() -> ImageTexture:
	if _cached_radial_texture:
		return _cached_radial_texture

	var size: int = 256
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0

	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x, y).distance_to(center)
			var a: float = clampf(1.0 - (d / radius), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))

	_cached_radial_texture = ImageTexture.create_from_image(img)
	return _cached_radial_texture

func _get_or_create_car_headlight_texture() -> ImageTexture:
	if _cached_car_texture:
		return _cached_car_texture

	var w: int = 512
	var h: int = 512
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var origin: Vector2 = Vector2(30.0, 256.0)
	var max_dist: float = 480.0
	var cone_angle: float = deg_to_rad(45.0)

	for y in range(h):
		for x in range(w):
			var diff: Vector2 = Vector2(x, y) - origin
			var dist: float = diff.length()
			if diff.x < 0 or dist > max_dist:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var ang: float = abs(diff.angle())
			if ang > cone_angle:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var dist_factor: float = pow(1.0 - (dist / max_dist), 1.3)
			var ang_factor: float = pow(1.0 - (ang / cone_angle), 1.6)

			# Две спаренные полосы (две фары автомобиля)
			var y_norm: float = (float(y) - 256.0) / (dist * 0.4 + 1.0)
			var dual_beam: float = maxf(
				exp(-pow(y_norm - 0.22, 2.0) * 8.0),
				exp(-pow(y_norm + 0.22, 2.0) * 8.0)
			)

			var alpha: float = dist_factor * ang_factor * (0.4 + dual_beam * 0.6)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))

	_cached_car_texture = ImageTexture.create_from_image(img)
	return _cached_car_texture
