extends CharacterBody2D

# Скорость передвижения персонажа (пикселей в секунду)
@export var speed: float = 240.0

# Параметры ускорения и торможения (устраняют дёрганье и резкие рывки)
@export var acceleration: float = 2200.0
@export var friction: float = 2600.0

# Блокировка управления во время диалогов и катсцен
var is_control_locked: bool = false
var movement_mode: String = "walk"
var dasha_animation: DashaAnimation
var held_flashlight: HeldFlashlight

# Визуальная моделька и анимация персонажа (Даша)
@onready var sprite: Sprite2D = get_node_or_null("DashaSprite") as Sprite2D

# Звуки шагов и столкновения со стенами
@onready var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
var _step_distance_accum: float = 0.0
var _walk_distance: float = 0.0
const STEP_DISTANCE: float = 82.0
var _bump_cooldown: float = 0.0
var _shake_strength: float = 0.0

func _ready() -> void:
	if sprite:
		dasha_animation = DashaAnimation.new()
		dasha_animation.setup(sprite)
		if has_node("Flashlight"):
			held_flashlight = HeldFlashlight.new()
			add_child(held_flashlight)
			held_flashlight.setup(self,dasha_animation)

func set_control_locked(locked: bool) -> void:
	is_control_locked = locked
	if locked and dasha_animation:
		dasha_animation.settle(movement_mode)

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
	
	# Плавный расчёт скорости (разгон и торможение без дёрганья)
	var target_velocity: Vector2 = input_vector * speed
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var prev_velocity: Vector2 = velocity
	var previous_position: Vector2 = global_position

	# Плавное скольжение вдоль стен и препятствий
	move_and_slide()

	# Обновление спрайта и микро-анимации шагов / покоя
	_walk_distance += previous_position.distance_to(global_position)
	_update_sprite_animation(delta)

	# 1. Звук шагов при активном перемещении
	var step_length: float = dasha_animation.step_distance(movement_mode) if dasha_animation else STEP_DISTANCE
	if not is_control_locked and velocity.length() > 28.0:
		_step_distance_accum += previous_position.distance_to(global_position)
		if _step_distance_accum >= step_length:
			_step_distance_accum = fmod(_step_distance_accum, step_length)
			var sound_mgr: Node = get_node_or_null("/root/SoundManager")
			if sound_mgr and sound_mgr.has_method("play_footstep"):
				sound_mgr.play_footstep(_footstep_surface(), -10.0 if movement_mode == "sneak" else 1.0 if movement_mode == "run" else 0.0)
	else:
		_step_distance_accum = step_length * 0.55

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

func _footstep_surface() -> String:
	var floor_root: Node = get_parent().get_node_or_null("Floor")
	if floor_root:
		for child: Node in floor_root.get_children():
			if child is Polygon2D and child.has_meta("footstep_surface"):
				var floor_polygon: Polygon2D = child as Polygon2D
				if Geometry2D.is_point_in_polygon(floor_polygon.to_local(global_position), floor_polygon.polygon):
					return str(child.get_meta("footstep_surface"))
	return "wood"

func _update_sprite_animation(delta: float) -> void:
	if dasha_animation:
		var desired: Vector2 = Vector2.ZERO if is_control_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if desired.is_zero_approx() and not is_control_locked and held_flashlight != null and (get_node("Flashlight").is_on() or held_flashlight.equip_amount > 0.0):
			var light: Flashlight = get_node("Flashlight") as Flashlight
			desired = light.body_direction_towards(get_global_mouse_position()) if light.input_enabled else Vector2.RIGHT.rotated(light.rotation)
		dasha_animation.update(delta, velocity, movement_mode, _walk_distance, is_control_locked, desired)
