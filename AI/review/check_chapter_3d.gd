extends SceneTree

var host: Node
var passed: int = 0
var failed: int = 0
var visual: bool = false
var route_checkpoint: Dictionary = {}

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func run() -> void:
	host = load("res://scenes/chapter_1_3d/apartment.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	await process_frame
	host.ui.close()
	for i: int in 12: await physics_frame
	while not host.navigation_ready: await physics_frame
	await process_frame
	await physics_frame
	check(host.world.rooms.size() == 14, "14 zones built")
	check(host.viewport_3d.size == Vector2i(640, 360), "low resolution world")
	check(host.player.visual.get_child_count() > 0, "Meshy model imported")
	var rig_nodes: Array[Node] = host.player.visual.find_children("*", "Skeleton3D", true, false)
	check(rig_nodes.size() == 1 and (rig_nodes[0] as Skeleton3D).get_bone_count() == 31, "rigged Dasha used in 3D prototype")
	await movement_fixture()
	host.world.update_visibility(host.player.position, host.camera)
	check(host.world.rooms.dressing.get_node("Floor").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "neighbouring room remains visible")
	check(host.world.has_node("BuildingContext/Foundation") and host.world.has_node("BuildingContext/Street"), "building grounded in street context")
	check(not host.state.has("dose"), "no automatic first dose")
	check(not root.get_node("ParanoiaManager").is_decay_active, "no passive stress decay")
	check(not host._target_available("pills"), "pills gated by bed search")
	# Physical proximity is required even if an ID is supplied directly.
	host.interact("bed")
	check(not host.state.has("bed"), "remote interaction rejected")
	await approach("bed")
	host.interact("bed")
	check(host.state.has("bed"), "bed searched through proximity selection")
	await approach("pills")
	host.interact("pills")
	check(root.get_node("InventoryManager").get_item_count("pills") == 2, "exactly two pills")
	host.ui.inventory("pills")
	root.get_node("InventoryManager").use_item("pills")
	host.ui.close()
	await process_frame
	check(host.state.has("dose") and root.get_node("InventoryManager").get_item_count("pills") == 1, "first inventory dose leaves one")
	var before: float = host.state.charge
	host.state.mark("phone_charging")
	host.ui.open("test", "Pause charge")
	for i: int in 6: await physics_frame
	check(host.state.charge == before, "modal freezes charge")
	host.ui.close()
	host.state.flags.erase("phone_charging")
	var schema: GDScript = load("res://scripts/chapter_1_3d/save_schema.gd")
	var data: Dictionary = host.export_chapter_save()
	check(schema.valid(data), "3D save schema accepts live snapshot")
	var bad: Dictionary = data.duplicate(true)
	bad.player.z = "wrong"
	check(not schema.valid(bad), "rejects invalid XYZ")
	bad = data.duplicate(true)
	bad.version = 3
	check(not schema.valid(bad), "rejects 2D format")
	bad = data.duplicate(true)
	bad.checkpoint = data.duplicate(true)
	bad.checkpoint.checkpoint = data.duplicate(true)
	check(not schema.valid(bad), "rejects recursive checkpoint")
	check(host.save_slot("slot_1"), "isolated save write")
	check(host.save_slot("slot_1"), "atomic replacement existing slot")
	check(not host.save_slot("../escape"), "slot path whitelist")
	var original: Vector3 = host.player.position
	host.player.position += Vector3(0.4, 0, 0)
	check(host.load_slot("slot_1") and host.player.position.is_equal_approx(original), "load restores XYZ")
	check(not host.world.clear_line(Vector3(-8, 1, -3), Vector3(-8, 5.5, -3)), "floor blocks cross-floor ray")
	check(not host.world.clear_line(Vector3(0, 5.2, 6.4), Vector3(0, 5.2, 7.6)), "closed study door blocks vision")
	var map: RID = host.world.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(map)
	check(NavigationServer3D.map_get_iteration_id(map) > 0, "navigation synchronized")
	var upstairs: Vector3 = Vector3(-8, 4.45, 3)
	var downstairs: Vector3 = Vector3(-8, 0.25, 0)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, upstairs, downstairs, true)
	if path.is_empty() or path[path.size() - 1].distance_to(downstairs) >= 0.7: print("MAIN NAV DEBUG ", path)
	check(path.size() > 2 and path[path.size() - 1].distance_to(downstairs) < 0.7, "main stairs join floors in navmesh")
	var service_path: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(10, 0.25, 2), Vector3(10, 4.45, 11), true)
	if service_path.is_empty() or service_path[service_path.size() - 1].distance_to(Vector3(10, 4.45, 11)) >= 0.7: print("SERVICE NAV DEBUG ", service_path)
	check(service_path.size() > 2 and service_path[service_path.size() - 1].distance_to(Vector3(10, 4.45, 11)) < 0.7, "service stairs join floors in navmesh")
	host.world.set_study_open(true)
	await physics_frame
	await physics_frame
	await physics_frame
	check(host.world.clear_line(Vector3(0, 5.2, 6.4), Vector3(0, 5.2, 7.6)), "open study door clears physical ray")
	host.world.set_study_open(false)
	if "--route" in OS.get_cmdline_user_args():
		await route()
		if host.state.has("coat"): await encounter_fixtures()
	if "--enemy-only" in OS.get_cmdline_user_args(): await enemy_stair_fixture()
	if visual:
		await audible_step_fixture()
		await capture("bedroom")
		for id: String in ApartmentLayout3D.ROOMS:
			if id == "bedroom": continue
			host.player.position = ApartmentLayout3D.center(id) + Vector3(1.3, 0.1, 1.0)
			host._update_camera(true)
			await capture(id)
		root.size = Vector2i(960, 600)
		host.ui.inventory("pills")
		for i: int in 4: await process_frame
		check(host.ui.modal.position.x >= 0 and host.ui.modal.position.y >= 0 and host.ui.modal.position.x + host.ui.modal.size.x <= host.ui.root.size.x + 1 and host.ui.modal.position.y + host.ui.modal.size.y <= host.ui.root.size.y + 1, "3D inventory fits 960x600")
		host.ui.close()
	print("3D CHECKS: ", passed, " passed, ", failed, " failed")
	host.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

func dismiss() -> void:
	while host.ui.modal_kind == "message": host.ui.advance_message()
	if not host.ui.modal_kind.is_empty(): host.ui.close()
	for i: int in 3: await physics_frame

func movement_fixture() -> void:
	var original: Vector3 = host.player.position
	var original_yaw: float = host.player.visual.rotation.y
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		host.player.position = Vector3(-8, 4.25, 3)
		host.player.velocity = Vector3.ZERO
		host.player.previous_input = Vector2.ZERO
		host._update_camera(true)
		host.world.update_visibility(host.player.position, host.camera, host.room_id)
		var before_visibility: int = visibility_signature()
		var stable_visibility: bool = true
		var start: Vector3 = host.player.position
		var emissions_before: int = host.player.step_emissions
		Input.action_press(action)
		for i: int in 40:
			await physics_frame
			if visibility_signature() != before_visibility: stable_visibility = false
		check(stable_visibility, "walking never hides wall or furniture geometry " + action)
		var direction: Vector3 = host.player.velocity
		direction.y = 0
		var mesh: Node3D = host.player.visual.get_child(0)
		var screen_delta: Vector2 = host.camera.unproject_position(host.player.position) - host.camera.unproject_position(start)
		var expected: Vector2 = {"move_up": Vector2.UP, "move_down": Vector2.DOWN, "move_left": Vector2.LEFT, "move_right": Vector2.RIGHT}[action]
		check(screen_delta.normalized().dot(expected) > 0.99, "movement matches screen perspective " + action)
		check(host.player.step_emissions > emissions_before, "walking actually triggers footsteps " + action)
		check(host.player.position.distance_to(start) > 0.4 and mesh.global_basis.z.normalized().dot(direction.normalized()) > 0.97, "character faces actual movement " + action)
		if action == "move_up":
			host.camera.rotation.y += PI * 0.5
			for i: int in 4: await physics_frame
			var after: Vector3 = host.player.velocity
			after.y = 0
			check(direction.normalized().dot(after.normalized()) > 0.97, "held movement survives camera angle change")
		Input.action_release(action)
		await physics_frame
	host.player.position = original
	host.player.velocity = Vector3.ZERO
	host.player.previous_input = Vector2.ZERO
	host.player.visual.rotation.y = original_yaw
	host._update_camera(true)
	host.world.update_visibility(original, host.camera, host.room_id)
	await occlusion_fixture()

func occlusion_fixture() -> void:
	var root_node: Node3D = Node3D.new()
	host.world.add_child(root_node)
	var mat: Material = host.world.material("wood", Color.WHITE)
	var blocking: MeshInstance3D = host.world.box(root_node, "BlockingProp", Vector3(40, 5, 35), Vector3(2, 3, 1), mat)
	var beside: MeshInstance3D = host.world.box(root_node, "BesideProp", Vector3(44, 5, 35), Vector3(2, 3, 1), mat)
	var decoration: MeshInstance3D = host.world.box(root_node, "MountedDecor", Vector3(41.1, 5, 35.7), Vector3(0.2, 0.2, 0.1), mat)
	decoration.set_meta("support_mesh", blocking)
	var test_camera: Camera3D = Camera3D.new()
	root_node.add_child(test_camera)
	test_camera.position = Vector3(40, 5, 40)
	var helper: RefCounted = load("res://scripts/chapter_1_3d/view_occlusion.gd").new()
	helper.collect(root_node)
	for i: int in 10: helper.update(test_camera, Vector3(40, 4, 30), 0.05)
	check(blocking.transparency > 0.65 and blocking.transparency < 0.8, "occluding prop becomes translucent, never invisible")
	check(beside.transparency == 0 and blocking.material_override == beside.material_override, "non-occluding prop remains opaque with shared material")
	check(is_equal_approx(decoration.transparency, blocking.transparency), "mounted decor follows its supporting wall opacity")
	blocking.position.z = 25
	for i: int in 14: helper.update(test_camera, Vector3(40, 4, 30), 0.05)
	check(blocking.transparency == 0, "object behind character restores opacity")
	root_node.queue_free()
	var sound: Node = root.get_node("SoundManager")
	sound.play_heartbeat_pulse(150, 1.0)
	check(not sound._heart_s1_player.playing and not sound._heart_s2_player.playing and sound._pending_dub < 0, "3D heartbeat audio disabled")
	check(root.get_node("ParanoiaManager").is_active, "stress remains active without heartbeat audio")
	var samples_valid: bool = true
	for variants: Array in host.player.footstep_sets.values():
		for stream: AudioStream in variants:
			if stream == null or stream.get_length() <= 0: samples_valid = false
	check(samples_valid and host.player.footstep_sets.size() == 2, "user-recorded footsteps decode successfully")
	check(host.player.footstep_sets.wood.size() == 6, "six natural steps from user recording")
	var smooth_edges: bool = true
	for stream: AudioStreamWAV in host.player.footstep_sets.wood:
		if stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.data.decode_s16(0) != 0 or stream.data.decode_s16(stream.data.size() - 2) != 0: smooth_edges = false
	check(smooth_edges, "user step cuts have click-free endpoints")
	check(host.viewport_3d.audio_listener_enable_3d, "3D viewport audio listener enabled")
	var overlaps: bool = false
	var walls: Array = host.world.walls
	for i: int in walls.size():
		var a: AABB = walls[i].global_transform * walls[i].get_aabb()
		for j: int in range(i + 1, walls.size()):
			var b: AABB = walls[j].global_transform * walls[j].get_aabb()
			if absf(a.position.y - b.position.y) > 0.1: continue
			if a.size.x > 0.16 and b.size.x > 0.16 and absf(a.position.z - b.position.z) < 0.001 and minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) > 0.001: overlaps = true
			if a.size.z > 0.16 and b.size.z > 0.16 and absf(a.position.x - b.position.x) < 0.001 and minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z) > 0.001: overlaps = true
	check(not overlaps, "no overlapping coplanar wall surfaces")
	var windows_supported: bool = true
	for mesh: MeshInstance3D in host.world.window_parts:
		if not mesh.has_meta("support_mesh"):
			windows_supported = false
			print("WINDOW SUPPORT DEBUG ", mesh.get_path(), " anchor=", mesh.get_parent().get_meta("wall_anchor"))
	check(windows_supported and host.world.window_parts.size() > 0, "window assemblies anchored to supporting walls")

func audible_step_fixture() -> void:
	for source: AudioStreamPlayer3D in host.world.ambient_sources: source.stop()
	host.player.footstep_player.stop()
	# Flush already mixed spatial rain/previous steps before capturing centred Foley.
	await create_timer(0.2).timeout
	var bus: int = AudioServer.get_bus_index("SFX")
	var index: int = AudioServer.get_bus_effect_count(bus)
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	# The default 100 ms buffer can fill with silence before the audio thread
	# starts a voice. Retain the full capture interval instead of discarding it.
	capture.buffer_length = 0.8
	AudioServer.add_bus_effect(bus, capture)
	capture.clear_buffer()
	host.player.play_step()
	check(host.player.footstep_player.pitch_scale == 1.0, "user step pitch preserved")
	await create_timer(0.45).timeout
	var buffer: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0
	var channel_difference: float = 0
	for frame: Vector2 in buffer:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		channel_difference = maxf(channel_difference, absf(frame.x - frame.y))
	check(peak > 0.0001, "footstep produces audible signal on SFX bus")
	check(channel_difference < maxf(0.00001, peak * 0.001), "own footsteps remain centred in stereo")
	check(host.player.footstep_player.volume_db <= -18.0, "walking footstep gain reduced to minus 18 dB")
	AudioServer.remove_bus_effect(bus, index)
	for source: AudioStreamPlayer3D in host.world.ambient_sources: source.play()

func visibility_signature() -> int:
	var values: Array = []
	for wall: MeshInstance3D in host.world.walls:
		values.append(wall.cast_shadow)
	for trim: MeshInstance3D in host.world.architectural_trim: values.append(trim.cast_shadow)
	for attachment: MeshInstance3D in host.world.wall_attachments: values.append(attachment.cast_shadow)
	for room: Node in host.world.rooms.values(): append_mesh_visibility(room, values)
	return values.hash()

func append_mesh_visibility(node: Node, values: Array) -> void:
	if node is MeshInstance3D:
		values.append(node.visible)
		values.append(node.cast_shadow)
	for child: Node in node.get_children(): append_mesh_visibility(child, values)

func route() -> void:
	Engine.time_scale = 4.0
	# Continue after the real bed/pills interactions; no quest flags are injected.
	for id: String in ["flashlight", "exit", "jacket", "key_rack", "study_door", "key_cabinet"]:
		if not await walk_to_object(id):
			Engine.time_scale = 1.0
			return
		host.interact(id)
		await dismiss()
	check(host.state.has("cabinet_checked"), "route discovers cabinet")
	host.story.pin.assign([2, 1, 4, 0])
	check(not host.story.try_pin(), "wrong clock code rejected")
	await dismiss()
	for id: String in ["desk_note", "wall_clock", "microwave", "service_log"]:
		if not await walk_to_object(id):
			Engine.time_scale = 1.0
			return
		host.interact(id)
		await dismiss()
	if not await walk_to_object("key_cabinet"):
		Engine.time_scale = 1.0
		return
	host.interact("key_cabinet")
	host.story.pin.assign([2, 1, 1, 7])
	check(host.story.try_pin(), "route solves 2117")
	await dismiss()
	if not await walk_to_object("sofa_search"):
		Engine.time_scale = 1.0
		return
	host.interact("sofa_search")
	check(host.state.documents.has("diary"), "route finds diary in sofa")
	host.ui.close()
	host.choose_diary("trust")
	for id: String in ["screwdriver", "fuse", "fusebox"]:
		if not await walk_to_object(id):
			Engine.time_scale = 1.0
			return
		host.interact(id)
		if id != "fusebox": await dismiss()
	host.story.breakers.assign([true, false, true])
	check(not host.story.try_power(), "faulty power circuit rejected")
	host.story.breakers.assign([true, true, false])
	check(host.story.try_power(), "optional power repair")
	await dismiss()
	if not await walk_to_object("exit"):
		Engine.time_scale = 1.0
		return
	host.interact("exit")
	host.story.latch.assign([2, 0, 1])
	check(host.story.try_latch(), "route frees mechanical bolt")
	await dismiss()
	host.interact("exit")
	check(host.ui.modal_kind == "qte", "route reaches coat QTE")
	for i: int in 10: host.ui.qte_press(host.ui.qte_next)
	await process_frame
	await process_frame
	await dismiss()
	check(host.state.has("coat") and not host.checkpoint_data.is_empty(), "coat checkpoint created")
	route_checkpoint = host.checkpoint_data.duplicate(true)
	var count: int = root.get_node("InventoryManager").get_item_count("pills")
	host.begin_encounter()
	check(is_instance_valid(host.enemy), "encounter spawns 3D enemy")
	host.retry_checkpoint()
	check(not is_instance_valid(host.enemy) and root.get_node("InventoryManager").get_item_count("pills") == count, "retry restores pre-encounter resources")
	Engine.time_scale = 1.0

func encounter_fixtures() -> void:
	# Isolated post-investigation fixtures; not claimed as a player-driven route.
	Engine.time_scale = 4.0
	host.retry_checkpoint()
	host.begin_encounter()
	await enemy_stair_fixture()
	host.enemy.position = Vector3(-8, 0.05, -3)
	host.player.position = Vector3(-8, 4.25, -3)
	host.enemy.grace = 0
	check(not host.enemy.sees_player(), "enemy cannot see through floor")
	for outcome: String in ["restrained", "lethal"]:
		host.retry_checkpoint()
		host.begin_encounter()
		host.player.position = Vector3(-8, 0.05, 0)
		host.enemy.position = Vector3(-8, 0.05, -1)
		host.enemy.stun(12)
		root.get_node("InventoryManager").add_item("rope", "Шнур", 1, "", "Fixture")
		root.get_node("InventoryManager").add_item("heavy", "Сковорода", 1, "", "Fixture")
		check(host.resolve_enemy(outcome), "fixture resolves " + outcome)
		check(not host.resolve_enemy(outcome), "outcome cannot repeat " + outcome)
		check(host.state.chaos_total() == (2 if outcome == "lethal" else 0), "consequences " + outcome)
		check(load("res://scripts/chapter_1_3d/save_schema.gd").valid(host.export_chapter_save()), "resolved save valid " + outcome)
		# Restore the pre-encounter snapshot retained by the route fixture.
		host.checkpoint_data = route_checkpoint.duplicate(true)
		host.retry_checkpoint()
	host.begin_encounter()
	host.player.position = Vector3(-10.5, 0.05, -5.0)
	host.enemy.position = Vector3(8, 0.05, 3)
	host.enemy.grace = 0
	check(host.can_escape(), "stealth exit available after losing enemy")
	host.finish_scene("stealth")
	check(host.state.phase == "complete" and host.state.outcome == "stealth", "stealth ending recorded")
	host.ui.close()
	host.checkpoint_data = route_checkpoint.duplicate(true)
	host.retry_checkpoint()
	Engine.time_scale = 1.0

func enemy_stair_fixture() -> void:
	Engine.time_scale = 4.0
	host.state.phase = "encounter"
	if not is_instance_valid(host.enemy): host._spawn_enemy()
	host.player.torch.visible = false
	var cases: Array[Array] = [["main", Vector3(-14, 0.05, -4), Vector3(-10.5, 4.25, 6)], ["service", Vector3(14, 0.05, 1.5), Vector3(10.5, 4.25, 12.5)]]
	for row: Array in cases:
		host.enemy.position = row[1]
		host.enemy.velocity = Vector3.ZERO
		host.player.position = row[2]
		host.player.velocity = Vector3.ZERO
		host.enemy.grace = 1000
		host.enemy.mode = ApartmentEnemy3D.Mode.INVESTIGATE
		host.enemy.last_known = host.player.position
		host.enemy.path_timer = 0
		host.enemy.path_initialized = false
		host.enemy.stuck_time = 0
		var climbed: bool = false
		for i: int in 600:
			await physics_frame
			if host.enemy.position.y > 4 and host.enemy.position.distance_to(host.player.position) < 1.2:
				climbed = true
				break
		check(climbed, "enemy physically climbs " + row[0] + " staircase and enters upper room")
		if not climbed:
			print("ENEMY STAIR DEBUG ", host.enemy.position, " mode=", host.enemy.mode, " vel=", host.enemy.velocity, " next=", host.enemy.agent.get_next_path_position())
			for n: int in host.enemy.get_slide_collision_count():
				var hit: KinematicCollision3D = host.enemy.get_slide_collision(n)
				print("HIT ", hit.get_collider().get_path(), " normal=", hit.get_normal())
	Engine.time_scale = 1.0

func walk_to_object(id: String) -> bool:
	var object: Node3D = host.world.interactables[id]
	var map: RID = host.world.get_world_3d().navigation_map
	var best: PackedVector3Array = PackedVector3Array()
	var best_length: float = INF
	var floor_y: float = 4.2 if object.position.y > 3 else 0.0
	for n: int in 24:
		var angle: float = TAU * float(n) / 24
		var candidate: Vector3 = Vector3(object.position.x + cos(angle) * 1.1, floor_y + 0.3, object.position.z + sin(angle) * 1.1)
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
		if closest.distance_to(candidate) > 0.5 or absf(closest.y - floor_y) > 0.6: continue
		var foot: Vector3 = Vector3(closest.x, floor_y + 0.05, closest.z)
		var expected_distance: float = host.target_distance(foot, object.position)
		if expected_distance > 1.5: continue
		var competing: bool = false
		for other_id: String in host.world.interactables:
			if other_id == id or not host._target_available(other_id): continue
			var other: Node3D = host.world.interactables[other_id]
			if host.target_distance(foot, other.position) < expected_distance and host.world.clear_line(foot + Vector3.UP * 1.5, other.position + Vector3.UP * 0.12): competing = true
		if competing: continue
		var end: Vector3 = object.position + Vector3.UP * 0.12
		if id in ["study_door", "study_door_side"]: end += end.direction_to(foot + Vector3.UP * 1.5) * 0.35
		if not host.world.clear_line(foot + Vector3.UP * 1.5, end): continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, host.player.position, closest, true)
		if path.is_empty() or path[path.size() - 1].distance_to(closest) > 0.5: continue
		var length: float = 0
		for i: int in path.size() - 1: length += path[i].distance_to(path[i + 1])
		if length < best_length:
			best_length = length
			best = path
	if best.is_empty():
		print("APPROACH DEBUG ", id, " from=", host.player.position, " object=", object.position, " closest=", NavigationServer3D.map_get_closest_point(map, object.position - Vector3.UP + Vector3.BACK))
		for link: NavigationLink3D in host.world.door_links: print("DOOR DEBUG ", link.enabled, " ", link.start_position, " -> ", NavigationServer3D.map_get_closest_point(map, link.start_position), " / ", link.end_position, " -> ", NavigationServer3D.map_get_closest_point(map, link.end_position))
		check(false, "route no reachable approach " + id)
		return false
	host.player.set_physics_process(false)
	for waypoint: Vector3 in best:
		var arrived: bool = false
		for i: int in 600:
			await physics_frame
			var offset: Vector3 = waypoint - host.player.position
			offset.y = 0
			if offset.length() < 0.055:
				arrived = true
				break
			var speed: float = clampf(offset.length() / host.player.get_physics_process_delta_time() * 0.65, 1.3, 3.5)
			host.player.velocity.x = offset.normalized().x * speed
			host.player.velocity.z = offset.normalized().z * speed
			host.player.velocity.y -= 18 * host.player.get_physics_process_delta_time()
			host.player.move_in_world()
		if not arrived:
			check(false, "route physics blocked " + id + " at " + str(host.player.position) + " toward " + str(waypoint))
			host.player.set_physics_process(true)
			return false
	host.player.velocity = Vector3.ZERO
	host.player.set_physics_process(true)
	host._update_target()
	if host.selected != id: print("CONTEXT DEBUG ", id, " player=", host.player.position, " target=", object.position, " distance=", host.player.position.distance_to(object.position), " ray=", host.world.clear_line(host.player.position + Vector3.UP * 1.5, object.position + Vector3.UP * 0.12))
	check(host.selected == id, "route context selects " + id + " (selected " + host.selected + ")")
	return host.selected == id

func approach(id: String) -> void:
	# Proximity fixture: selection and line-of-sight are real; this is not a full route test.
	var object: Node3D = host.world.interactables[id]
	for n: int in 24:
		var angle: float = TAU * float(n) / 24.0
		host.player.position = Vector3(object.position.x + cos(angle) * 0.9, 4.25, object.position.z + sin(angle) * 0.9)
		host.player.velocity = Vector3.ZERO
		await physics_frame
		host._update_target()
		if host.selected == id: return
	check(false, "cannot approach " + id)

func capture(label: String) -> void:
	host.ui.close()
	for i: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("KAMDRAAA_3D_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	print("CAPTURE ", output.path_join(label + ".png"))
