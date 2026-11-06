class_name ApartmentPlayer3D
extends CharacterBody3D

const MOVE_SPEED: Dictionary = {"walk": 1.4, "run": 3.6, "sneak": 0.62}
const SLOPE_SPEED: Dictionary = {"walk": 1.0, "run": 1.5, "sneak": 0.55}
const ACCELERATION: Dictionary = {"walk": 6.0, "run": 8.5, "sneak": 3.2}
const DECELERATION: float = 8.5

var host: Node
var control_locked: bool = false
var visual: Node3D
var torch: SpotLight3D
var movement_mode: String = "walk"
var held_basis: Basis = Basis.IDENTITY
var previous_input: Vector2 = Vector2.ZERO
var footstep_player: AudioStreamPlayer
var footstep_sets: Dictionary = {}
var last_step: int = -1
var step_emissions: int = 0
var held_room: String = ""
var held_direction: Vector3 = Vector3.ZERO
var locomotion: DashaAnimation3D = DashaAnimation3D.new()

func setup(controller: Node) -> void:
	host = controller
	name = "Player"
	collision_layer = 4
	collision_mask = 3 | 8
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = 0.86
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var model: PackedScene = load("res://assets/models/characters/dasha_meshy/locomotion_v2/dasha_locomotion.glb") as PackedScene
	if model:
		var mesh: Node3D = model.instantiate() as Node3D
		mesh.position.y = 0.952
		# Meshy faces +Z; the controller and Godot cameras use -Z forward.
		# Correct the imported asset once, keeping movement/save yaw unchanged.
		mesh.rotation.y = PI
		visual.add_child(mesh)
		locomotion.setup(mesh)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.24, 1.2, -0.22)
	torch.light_color = Color("e8dfbb")
	torch.light_energy = 5.0
	torch.spot_range = 12.0
	torch.spot_angle = 28.0
	torch.spot_attenuation = 1.3
	torch.shadow_enabled = true
	torch.visible = false
	add_child(torch)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(0, 1.5, 0.4)
	fill.omni_range = 1.8
	fill.light_energy = 0.45
	fill.light_color = Color("b6c1cf")
	add_child(fill)
	# Own-body Foley stays centred, independent of camera/listener orientation.
	footstep_player = AudioStreamPlayer.new()
	footstep_player.bus = "SFX"
	footstep_player.max_polyphony = 2
	add_child(footstep_player)
	for surface: String in ["wood", "concrete"]:
		var variants: Array[AudioStreamWAV] = []
		for index: int in 6:
			variants.append(AudioStreamWAV.load_from_file("res://assets/audio/footsteps_user/step_%02d.wav" % index))
		footstep_sets[surface] = variants

func set_control_locked(value: bool) -> void:
	control_locked = value
	if value: velocity = Vector3.ZERO

func apply_shake(_amount: float) -> void:
	pass

func _process(delta: float) -> void:
	# Shared dialogue UI disables physics input; the body can still breathe.
	if not is_physics_processing():
		locomotion.update(delta, Vector3.ZERO, is_on_floor(), movement_mode, false, true)

func _physics_process(delta: float) -> void:
	if control_locked or host.is_blocked():
		locomotion.update(delta, Vector3.ZERO, is_on_floor(), movement_mode, false, true)
		return
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != previous_input:
		held_basis = host.camera.global_basis
		held_room = host.room_id
		held_direction = screen_direction(input)
	elif held_room == host.room_id and held_basis.z.dot(host.camera.global_basis.z) > 0.9999:
		held_direction = screen_direction(input)
	if input.is_zero_approx(): held_direction = Vector3.ZERO
	previous_input = input
	var direction: Vector3 = held_direction
	# Finish braking in the current gait instead of switching a running body to
	# a fast walk clip immediately when the direction keys are released.
	if not input.is_zero_approx():
		movement_mode = "sneak" if Input.is_action_pressed("sneak") else ("run" if Input.is_action_pressed("run") else "walk")
	var on_slope: bool = is_on_floor() and get_floor_normal().y < 0.98
	var speed: float = float(SLOPE_SPEED[movement_mode] if on_slope else MOVE_SPEED[movement_mode])
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var target_velocity: Vector3 = direction * speed
	var acceleration: float = DECELERATION if direction.is_zero_approx() or target_velocity.length_squared() < horizontal.length_squared() else float(ACCELERATION[movement_mode])
	horizontal = horizontal.move_toward(target_velocity, delta * acceleration)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= 18.0 * delta
	var previous_position: Vector3 = position
	move_in_world()
	var displacement: Vector3 = position - previous_position
	var travelled: Vector3 = Vector3(displacement.x, 0.0, displacement.z)
	# Slide contacts can replace the requested velocity. Facing follows the
	# actual path along walls instead of turning toward an obstructed target.
	if travelled.length() > delta * DashaAnimation3D.MIN_MOVING_SPEED and travelled.length() < 0.5:
		face_direction(travelled.normalized(), delta)
	var contacts: int = locomotion.update(delta, displacement, is_on_floor(), movement_mode, get_floor_normal().y < 0.98)
	if contacts > 0: play_step()
	var target: Vector3 = host.mouse_world()
	target.y = torch.global_position.y
	if target.distance_to(torch.global_position) > 0.15:
		torch.look_at(target, Vector3.UP)

func move_in_world() -> void:
	preload("res://scripts/chapter_1_3d/actor_motion.gd").move_actor(self)

func face_direction(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.001: return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 9.5))

func play_step() -> void:
	var room: String = ApartmentLayout3D.room_at(position)
	var surface: String = "wood" if ApartmentLayout3D.ROOMS[room][3] == "wood" else "concrete"
	var count: int = footstep_sets[surface].size()
	var index: int = randi_range(0, count - 2)
	if index >= last_step: index += 1
	last_step = index
	footstep_player.stream = footstep_sets[surface][index]
	footstep_player.pitch_scale = 1.0
	footstep_player.volume_db = {"walk": -18.0, "run": -15.0, "sneak": -27.0}[movement_mode]
	footstep_player.play()
	step_emissions += 1

func screen_direction(input: Vector2) -> Vector3:
	if input.is_zero_approx(): return Vector3.ZERO
	var camera: Camera3D = host.camera
	var screen: Vector2 = camera.unproject_position(global_position) + input * 48.0
	var point: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if point == null: return Vector3.ZERO
	var offset: Vector3 = (point as Vector3) - global_position
	offset.y = 0
	return offset.normalized()
