class_name ApartmentEnemy
extends CharacterBody2D

enum Mode { SEARCH, INVESTIGATE, CHASE, STUNNED, RESTRAINED, DEAD }
var host: Node2D
var mode: Mode = Mode.SEARCH
var last_known: Vector2
var facing: Vector2 = Vector2.DOWN
var state_time: float = 0.0
var lost_time: float = 0.0
var capture_time: float = 0.0
var stun_time: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_timer: float = 0.0
var patrol_index: int = 0
var grace: float = 3.0

func setup(controller: Node2D) -> void:
	host = controller
	name = "Unknown"
	collision_layer = 2
	collision_mask = 5
	light_mask = 4
	var collision: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 13.0
	collision.shape = circle
	add_child(collision)
	last_known = ApartmentWorld.iso(Vector2(800, 500))

func _draw() -> void:
	draw_ellipse_shadow()
	var fallen: bool = mode in [Mode.DEAD, Mode.RESTRAINED]
	var shift: Vector2 = Vector2(25, 52) if fallen else Vector2.ZERO
	var coat: PackedVector2Array = PackedVector2Array([Vector2(-17, -65), Vector2(14, -67), Vector2(22, -21), Vector2(13, -12), Vector2(-16, -12), Vector2(-22, -28)])
	for i: int in coat.size(): coat[i] += shift
	draw_colored_polygon(coat, Color("262735"))
	draw_line(Vector2(-8, -17) + shift, Vector2(-9, -1) + shift, Color("151b27"), 9)
	draw_line(Vector2(9, -17) + shift, Vector2(10, 1) + shift, Color("151b27"), 9)
	draw_circle(Vector2(0, -76) + shift, 12.0, Color("4b4e5b"))
	draw_style_mask(shift)
	if mode == Mode.STUNNED:
		draw_arc(Vector2(0, -92), 15, 0, TAU * 0.8, 18, Color("dccb8e"), 2)
	if mode == Mode.RESTRAINED:
		draw_line(Vector2(-3, 23), Vector2(45, 28), Color("b4a78a"), 3)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0, Color(0.03, 0.04, 0.08, 0.55))
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.55, 1.55))

func draw_style_mask(shift: Vector2) -> void:
	var mask_points: PackedVector2Array = PackedVector2Array([Vector2(-10, -81), Vector2(10, -81), Vector2(8, -68), Vector2(-7, -65)])
	for i: int in mask_points.size(): mask_points[i] += shift
	draw_colored_polygon(mask_points, Color("9b9d9c"))
	draw_line(Vector2(-7, -77) + shift, Vector2(-2, -77) + shift, Color("242633"), 2)
	draw_line(Vector2(3, -77) + shift, Vector2(8, -77) + shift, Color("242633"), 2)

func sees_player() -> bool:
	if mode in [Mode.DEAD, Mode.RESTRAINED, Mode.STUNNED] or host.hidden_player or grace > 0.0:
		return false
	var offset: Vector2 = host.player.global_position - global_position
	var distance: float = offset.length()
	var range_limit: float = 200.0 if host.sneaking and not host.flashlight.is_on() else 420.0
	return distance < range_limit and (distance < 95.0 or facing.dot(offset.normalized()) > -0.1) and host.world.clear_line(global_position, host.player.global_position)

func hear(point: Vector2) -> void:
	if mode in [Mode.STUNNED, Mode.RESTRAINED, Mode.DEAD] or global_position.distance_to(point) > 1100.0:
		return
	last_known = point
	mode = Mode.INVESTIGATE
	state_time = 0.0
	lost_time = 0.0
	path_timer = 0.0

func stun(duration: float) -> void:
	if mode in [Mode.RESTRAINED, Mode.DEAD]:
		return
	mode = Mode.STUNNED
	stun_time = maxf(stun_time, duration)
	capture_time = 0.0
	velocity = Vector2.ZERO
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.is_blocked() or host.state.phase != "encounter":
		return
	grace = maxf(0.0, grace - delta)
	state_time += delta
	if mode in [Mode.RESTRAINED, Mode.DEAD]:
		return
	if mode == Mode.STUNNED:
		stun_time -= delta
		if stun_time <= 0:
			mode = Mode.SEARCH
			state_time = 0.0
			queue_redraw()
		return
	if sees_player():
		mode = Mode.CHASE
		last_known = host.player.global_position
		lost_time = 0.0
	else:
		lost_time += delta
		if mode == Mode.CHASE and lost_time > 2.0:
			mode = Mode.INVESTIGATE
			state_time = 0.0
	if not host.sneaking and host.player.velocity.length() > 120.0 and global_position.distance_to(host.player.global_position) < (340.0 if host.player.movement_mode == "run" else 210.0) and mode != Mode.CHASE:
		hear(host.player.global_position)
	if mode == Mode.INVESTIGATE and (global_position.distance_to(last_known) < 32.0 or state_time > 10.0):
		mode = Mode.SEARCH
		state_time = 0.0
	if mode == Mode.SEARCH and (global_position.distance_to(last_known) < 45.0 or state_time > 9.0):
		var patrol: Array[Vector2] = [Vector2(800, 900), Vector2(430, 1230), Vector2(800, 1600), Vector2(1370, 1360), Vector2(800, 450)]
		last_known = ApartmentWorld.iso(patrol[patrol_index % patrol.size()])
		patrol_index += 1
		state_time = 0.0
	path_timer -= delta
	if path_timer <= 0:
		path = host.world.route(global_position, last_known)
		path_timer = 0.45
	while not path.is_empty() and global_position.distance_to(path[0]) < 24.0:
		path.remove_at(0)
	if not path.is_empty():
		facing = global_position.direction_to(path[0])
		velocity = facing * (155.0 if mode == Mode.CHASE else 105.0)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if global_position.distance_to(host.player.global_position) < 35.0 and not host.hidden_player and grace <= 0:
		capture_time += delta
		host.ui.notify("Он схватил Дашу. Отойдите или примените средство защиты!", 0.3)
		if capture_time >= 1.6:
			capture_time = 0.0
			host.fail_encounter()
	else:
		capture_time = maxf(0.0, capture_time - delta * 2.0)

func snapshot() -> Dictionary:
	return {"mode": mode, "x": position.x, "y": position.y, "target_x": last_known.x, "target_y": last_known.y, "stun": stun_time, "lost": lost_time, "state_time": state_time, "grace": grace, "patrol": patrol_index}

func restore(data: Dictionary) -> void:
	mode = clampi(int(data.get("mode", 0)), 0, Mode.DEAD) as Mode
	position = Vector2(float(data.get("x", 800)), float(data.get("y", 400)))
	last_known = Vector2(float(data.get("target_x", position.x)), float(data.get("target_y", position.y)))
	stun_time = float(data.get("stun", 0.0))
	lost_time = float(data.get("lost", 0.0))
	state_time = float(data.get("state_time", 0.0))
	grace = float(data.get("grace", 0.0))
	patrol_index = int(data.get("patrol", 0))
	path_timer = 0.0
	capture_time = 0.0
	queue_redraw()
