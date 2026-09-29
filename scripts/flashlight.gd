class_name Flashlight
extends Node2D

# Flashlight — Система карманного фонарика Даши с динамическими тенями
# Создает кинематографичный конусный луч света, отбрасывающий глубокие тени от стен и препятствий,
# и блокируемый всеми окклюдерами.

signal flashlight_toggled(is_on: bool)

@export var is_flashlight_on: bool = true
@export var beam_color: Color = Color(1.0, 0.97, 0.9, 1.0)
@export var ambient_color: Color = Color(0.85, 0.9, 1.0, 0.4)
@export var beam_energy: float = 1.3
@export var ambient_energy: float = 0.35
@export var smooth_speed: float = 14.0

var cone_light: PointLight2D
var ambient_light: PointLight2D

var _target_angle: float = 0.0
var _parent_body: CharacterBody2D
var _ignition_tween: Tween

# Кэшированные процедурные текстуры освещения
static var _cached_cone_texture: ImageTexture = null
static var _cached_radial_texture: ImageTexture = null

func _ready() -> void:
	_parent_body = get_parent() as CharacterBody2D
	_setup_lights()
	_update_light_states()

func _setup_lights() -> void:
	# 1. Основной направленный конусный луч (Spotlight с жесткими блокирующими тенями)
	cone_light = PointLight2D.new()
	cone_light.name = "ConeLight"
	cone_light.color = beam_color
	cone_light.energy = beam_energy
	cone_light.shadow_enabled = true
	cone_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	cone_light.shadow_color = Color(0.0, 0.0, 0.0, 0.0) # 100% блокировка свечения за стенами
	cone_light.texture = _get_or_create_cone_texture()
	cone_light.position = Vector2.ZERO
	cone_light.offset = Vector2.ZERO
	cone_light.texture_scale = 1.85
	add_child(cone_light)

	# 2. Мягкий рассеянный круговой свет вокруг Даши с тенями, чтобы не просвечивал сквозь стены
	ambient_light = PointLight2D.new()
	ambient_light.name = "AmbientLight"
	ambient_light.color = ambient_color
	ambient_light.energy = ambient_energy
	ambient_light.shadow_enabled = true
	ambient_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	ambient_light.shadow_color = Color(0.0, 0.0, 0.0, 0.0) # Не пробивает стены
	ambient_light.texture = _get_or_create_radial_texture()
	ambient_light.texture_scale = 1.2
	add_child(ambient_light)

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	var is_toggle_key: bool = false
	if event.is_action_pressed("toggle_flashlight"):
		is_toggle_key = true
	elif event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_F:
		is_toggle_key = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		is_toggle_key = true

	if is_toggle_key:
		get_viewport().set_input_as_handled()
		toggle_flashlight()

func toggle_flashlight(enable_state: Variant = null) -> void:
	if enable_state != null:
		is_flashlight_on = bool(enable_state)
	else:
		is_flashlight_on = not is_flashlight_on

	_update_light_states()

	# Звук щелчка карманного фонарика
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_flashlight_toggle"):
		sound_mgr.play_flashlight_toggle(is_flashlight_on)

	# Уведомление игроку
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.emit("🔦 Фонарик: %s [F / ПКМ]" % ("ВКЛЮЧЕН" if is_flashlight_on else "ВЫКЛЮЧЕН"))

	flashlight_toggled.emit(is_flashlight_on)

	# Эффект искры при включении
	if is_flashlight_on and cone_light:
		if _ignition_tween and _ignition_tween.is_valid():
			_ignition_tween.kill()
		cone_light.energy = beam_energy * 1.4
		_ignition_tween = create_tween()
		_ignition_tween.tween_property(cone_light, "energy", beam_energy * 0.85, 0.04)
		_ignition_tween.tween_property(cone_light, "energy", beam_energy, 0.06)

func is_on() -> bool:
	return is_flashlight_on

func _update_light_states() -> void:
	if cone_light:
		cone_light.enabled = is_flashlight_on
	if ambient_light:
		ambient_light.enabled = is_flashlight_on
		ambient_light.energy = ambient_energy if is_flashlight_on else 0.0

func _process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var mouse_angle: float = (mouse_pos - global_position).angle()

	# 1. Определение целевого направления луча
	if _parent_body and _parent_body.velocity.length() > 20.0:
		# Персонаж в движении: фонарик направляется за мышкой,
		# но ограничен радиусом 90 градусов (+/- 90°) относительно вектора движения
		var move_angle: float = _parent_body.velocity.angle()
		var diff: float = wrapf(mouse_angle - move_angle, -PI, PI)
		var max_radius: float = deg_to_rad(90.0)
		var clamped_diff: float = clampf(diff, -max_radius, max_radius)
		_target_angle = move_angle + clamped_diff
	else:
		# Персонаж стоит: свободный круговой обзор на 360° за курсором мыши
		if mouse_pos.distance_squared_to(global_position) > 10.0:
			_target_angle = mouse_angle

	# 2. Плавный кинематографичный поворот
	rotation = lerp_angle(rotation, _target_angle, delta * smooth_speed)

	# 3. Микро-покачивание руки (sway & organic breath)
	if is_flashlight_on:
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		var micro_flicker: float = (sin(time_sec * 40.0) * 0.015) + ((randf() - 0.5) * 0.01)
		if cone_light and not (_ignition_tween and _ignition_tween.is_running()):
			cone_light.energy = beam_energy * (1.0 + micro_flicker)

# ========================================================
# Процедурная генерация текстур освещения
# ========================================================

func _get_or_create_cone_texture() -> ImageTexture:
	if _cached_cone_texture:
		return _cached_cone_texture

	var size: int = 512
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)

	var origin: Vector2 = Vector2(float(size) / 2.0, float(size) / 2.0) # Точно по центру источника
	var max_dist: float = 245.0
	var cone_half_angle_rad: float = deg_to_rad(34.0) # Угол рассеивания луча ~68°
	var hotspot_angle_rad: float = deg_to_rad(10.0) # Центральный пучок

	for y in range(size):
		for x in range(size):
			var pos: Vector2 = Vector2(float(x), float(y))
			var diff: Vector2 = pos - origin
			var dist: float = diff.length()

			if diff.x < 0.0 or dist > max_dist:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var angle: float = abs(diff.angle())
			if angle > cone_half_angle_rad:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			# Радиальное затухание по дальности
			var dist_norm: float = dist / max_dist
			var dist_factor: float = pow(1.0 - dist_norm, 1.3)

			# Угловое затухание от центра к краям конуса (smoothstep)
			var angle_norm: float = angle / cone_half_angle_rad
			var angular_factor: float = clampf(1.0 - angle_norm, 0.0, 1.0)
			angular_factor = angular_factor * angular_factor * (3.0 - 2.0 * angular_factor)

			# Центральное горячее пятно
			var hotspot: float = 0.0
			if angle < hotspot_angle_rad:
				hotspot = (1.0 - (angle / hotspot_angle_rad)) * 0.4

			var final_alpha: float = dist_factor * (angular_factor * 0.65 + hotspot)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(final_alpha, 0.0, 1.0)))

	_cached_cone_texture = ImageTexture.create_from_image(img)
	return _cached_cone_texture

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
			var factor: float = clampf(1.0 - (d / radius), 0.0, 1.0)
			var alpha: float = factor * factor
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	_cached_radial_texture = ImageTexture.create_from_image(img)
	return _cached_radial_texture
