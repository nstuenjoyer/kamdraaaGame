extends CharacterBody2D

# Скорость передвижения персонажа (пикселей в секунду)
@export var speed: float = 240.0

# Параметры ускорения и торможения (устраняют дёрганье и резкие рывки)
@export var acceleration: float = 2200.0
@export var friction: float = 2600.0

# Блокировка управления во время диалогов и катсцен
var is_control_locked: bool = false

# Визуальная моделька и анимация персонажа (Даша)
@onready var sprite: Sprite2D = get_node_or_null("DashaSprite") as Sprite2D
var _base_scale: Vector2 = Vector2(0.17, 0.17)

# Звуки шагов и столкновения со стенами
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
var _step_distance_accum: float = 0.0
const STEP_DISTANCE: float = 52.0
var _bump_cooldown: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	if sprite:
		_base_scale = sprite.scale

func set_control_locked(locked: bool) -> void:
	is_control_locked = locked

func _process(delta: float) -> void:
	if _shake_strength > 0.0 and camera:
		_shake_strength = move_toward(_shake_strength, 0.0, delta * 18.0)
		camera.offset = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength))
	elif camera and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func apply_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)

func _physics_process(delta: float) -> void:
	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	if is_control_locked:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_sprite_animation(delta)
		return

	# Получаем направление движения по осям X и Y
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Запасной вариант: если действия в Input Map ещё не настроены,
	# считываем нажатия клавиш WASD и стрелок напрямую
	if input_vector == Vector2.ZERO:
		var raw_x: float = 0.0
		var raw_y: float = 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			raw_x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			raw_x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			raw_y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			raw_y += 1.0
		input_vector = Vector2(raw_x, raw_y).normalized()

	# Плавный расчёт скорости (разгон и торможение без дёрганья)
	var target_velocity: Vector2 = input_vector * speed
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var prev_velocity: Vector2 = velocity

	# Плавное скольжение вдоль стен и препятствий
	move_and_slide()

	# Обновление спрайта и микро-анимации шагов / покоя
	_update_sprite_animation(delta)

	# 1. Звук шагов при активном перемещении
	if not is_control_locked and velocity.length() > 28.0:
		_step_distance_accum += velocity.length() * delta
		if _step_distance_accum >= STEP_DISTANCE:
			_step_distance_accum = 0.0
			var sound_mgr: Node = get_node_or_null("/root/SoundManager")
			if sound_mgr and sound_mgr.has_method("play_footstep"):
				sound_mgr.play_footstep()
	else:
		_step_distance_accum = STEP_DISTANCE * 0.75

	# 2. Определение врезания в стены и препятствия
	if get_slide_collision_count() > 0 and _bump_cooldown <= 0.0:
		for i in range(get_slide_collision_count()):
			var col: KinematicCollision2D = get_slide_collision(i)
			var impact_speed: float = -prev_velocity.dot(col.get_normal())
			if impact_speed > 80.0:
				_bump_cooldown = 0.3
				var sound_mgr: Node = get_node_or_null("/root/SoundManager")
				if sound_mgr and sound_mgr.has_method("play_wall_bump"):
					sound_mgr.play_wall_bump()
				break

func _update_sprite_animation(delta: float) -> void:
	if not sprite:
		return

	var is_moving: bool = not is_control_locked and velocity.length() > 20.0

	# 1. Поворот спрайта по горизонтали
	# Исходный спрайт смотрит влево (3/4).
	# Если идём вправо (velocity.x > 0) -> отражаем flip_h = true.
	# Если идём влево (velocity.x < 0) -> flip_h = false.
	# При движении строго вверх/вниз сохраняем предыдущее направление.
	if velocity.x > 8.0:
		sprite.flip_h = true
	elif velocity.x < -8.0:
		sprite.flip_h = false

	# 2. Анимация шагов (боббинг) и дыхания (покой)
	if is_moving:
		# Фаза шага от 0 до 2*PI, синхронизированная с шагами
		var walk_phase: float = (_step_distance_accum / STEP_DISTANCE) * TAU
		# Подскок вверх-вниз при каждом шаге
		var bob_y: float = -abs(sin(walk_phase)) * 2.2
		# Мягкий наклон корпуса в такт движению
		var tilt: float = sin(walk_phase) * 0.025
		if sprite.flip_h:
			tilt = -tilt

		sprite.position.y = bob_y
		sprite.rotation = tilt
		sprite.scale = _base_scale
	else:
		# Плавное возвращение к нейтральной стойке
		sprite.position.y = move_toward(sprite.position.y, 0.0, delta * 14.0)
		sprite.rotation = move_toward(sprite.rotation, 0.0, delta * 6.0)

		# Мягкое дыхание в покое (микро-сквош и стретч)
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		var breath: float = sin(time_sec * 2.4) * 0.006
		sprite.scale = _base_scale * Vector2(1.0 - breath, 1.0 + breath)
