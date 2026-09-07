extends CharacterBody2D

# Скорость передвижения персонажа (пикселей в секунду)
@export var speed: float = 240.0

# Параметры ускорения и торможения (устраняют дёрганье и резкие рывки)
@export var acceleration: float = 2200.0
@export var friction: float = 2600.0

func _physics_process(delta: float) -> void:
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

	# Плавное скольжение вдоль стен и препятствий
	move_and_slide()
