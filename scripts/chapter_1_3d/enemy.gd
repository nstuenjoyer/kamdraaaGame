class_name ApartmentEnemy3D
extends CharacterBody3D

enum Mode { SEARCH, INVESTIGATE, CHASE, STUNNED, RESTRAINED, DEAD }
var host: Node
var mode: Mode = Mode.SEARCH
var agent: NavigationAgent3D
var last_known: Vector3
var facing: Vector3 = Vector3.FORWARD
var grace: float = 4.0
var stun_time: float = 0.0
var lost_time: float = 0.0
var capture_time: float = 0.0
var path_timer: float = 0.0
var patrol_index: int = 0
var stuck_time: float = 0.0
var previous_position: Vector3 = Vector3.ZERO
var path_initialized: bool = false

func setup(controller: Node) -> void:
	host = controller
	collision_layer = 2
	collision_mask = 5 | 8
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(42)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	var coat: Material = host.world.material("fabric", Color("252b31"))
	host.world.box(self, "Coat", Vector3(0, 0.95, 0), Vector3(0.56, 1.1, 0.32), coat)
	host.world.box(self, "Mask", Vector3(0, 1.65, -0.03), Vector3(0.26, 0.32, 0.26), host.world.material("wall", Color("a9aaa0")))
	for x: float in [-0.15, 0.15]: host.world.box(self, "Leg", Vector3(x, 0.25, 0), Vector3(0.18, 0.5, 0.21), coat)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.24
	agent.path_height_offset = 0.35
	agent.target_desired_distance = 0.65
	add_child(agent)
	last_known = ApartmentLayout3D.center("hall")

func sees_player() -> bool:
	if grace > 0 or mode in [Mode.STUNNED, Mode.RESTRAINED, Mode.DEAD] or host.hidden_player: return false
	var offset: Vector3 = host.player.global_position - global_position
	var limit: float = 3.0 if host.sneaking and not host.player.torch.visible else 7.5
	return offset.length() < limit and (offset.length() < 1.5 or facing.dot(offset.normalized()) > 0.05) and host.world.clear_line(global_position + Vector3.UP * 1.5, host.player.global_position + Vector3.UP * 1.3)

func hear(point: Vector3) -> void:
	if mode in [Mode.STUNNED, Mode.RESTRAINED, Mode.DEAD]: return
	if point.distance_to(global_position) > 13.0: return
	if not host.world.clear_line(global_position + Vector3.UP, point + Vector3.UP) and point.distance_to(global_position) > 3.0: return
	last_known = point
	mode = Mode.INVESTIGATE
	lost_time = 0.0
	path_timer = 0.0

func stun(duration: float) -> void:
	if mode in [Mode.RESTRAINED, Mode.DEAD]: return
	mode = Mode.STUNNED
	stun_time = maxf(stun_time, duration)
	capture_time = 0.0
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if host.is_blocked() or host.state.phase != "encounter": return
	grace = maxf(0, grace - delta)
	if mode in [Mode.RESTRAINED, Mode.DEAD]: return
	if mode == Mode.STUNNED:
		stun_time -= delta
		if stun_time <= 0: mode = Mode.SEARCH
		return
	if sees_player():
		mode = Mode.CHASE
		last_known = host.player.global_position
		lost_time = 0
	else:
		lost_time += delta
		if mode == Mode.CHASE and lost_time > 2.0: mode = Mode.INVESTIGATE
	if position.distance_to(previous_position) < 0.02: stuck_time += delta
	else: stuck_time = 0
	previous_position = position
	if host.player.movement_mode == "run" and host.player.velocity.length() > 1 and mode != Mode.CHASE: hear(host.player.global_position)
	if mode != Mode.CHASE and (global_position.distance_to(last_known) < 0.6 or stuck_time > 8):
		var patrol: Array[String] = ["living", "kitchen", "winter_garden", "guest", "gallery", "bedroom", "hall"]
		last_known = ApartmentLayout3D.center(patrol[patrol_index % patrol.size()])
		patrol_index += 1
		lost_time = 0
		mode = Mode.SEARCH
		stuck_time = 0
	path_timer -= delta
	if path_timer <= 0:
		# Reassigning an unchanged target restarts off-mesh traversal and makes
		# an actor oscillate at a stair's first link instead of walking across.
		var on_stair: bool = absf(position.x) > 12.2
		if not path_initialized or (not on_stair and agent.target_position.distance_to(last_known) > 0.35):
			agent.target_position = last_known
			path_initialized = true
		path_timer = 0.4
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0: return
	var target: Vector3 = agent.get_next_path_position()
	var direction: Vector3 = target - global_position
	direction.y = 0
	direction = direction.normalized()
	if direction.length() > 0.05: facing = direction.normalized()
	var speed: float = 2.25 if mode == Mode.CHASE else 1.45
	# Match the player's grounded stair pacing while retaining an escape margin.
	if is_on_floor() and get_floor_normal().y < 0.98:
		speed = minf(speed, 1.2 if mode == Mode.CHASE else 0.9)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= 18 * delta
	preload("res://scripts/chapter_1_3d/actor_motion.gd").move_actor(self)
	if global_position.distance_to(host.player.global_position) < 0.7 and not host.hidden_player and grace <= 0:
		capture_time += delta
		if capture_time >= 1.6:
			capture_time = 0
			host.fail_encounter()
	else: capture_time = 0

func snapshot() -> Dictionary:
	return {"mode": int(mode), "position": [position.x, position.y, position.z], "target": [last_known.x, last_known.y, last_known.z], "stun": stun_time, "grace": grace, "patrol": patrol_index, "lost": lost_time}

func restore(data: Dictionary) -> void:
	path_initialized = false
	mode = int(data.mode) as Mode
	position = Vector3(data.position[0], data.position[1], data.position[2])
	last_known = Vector3(data.target[0], data.target[1], data.target[2])
	stun_time = float(data.stun)
	grace = float(data.grace)
	patrol_index = int(data.patrol)
	lost_time = float(data.lost)
