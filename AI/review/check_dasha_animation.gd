extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if ok: passed += 1
	else: failed += 1

func run() -> void:
	var host: Node = load("res://scenes/chapter_1_3d/apartment.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	await process_frame
	host.skip_intro()
	host.ui.close()
	for i: int in 20: await physics_frame
	var actor: ApartmentPlayer3D = host.player
	var motion: DashaAnimation3D = actor.locomotion
	check(motion.clips.size() == 6, "six gameplay clips imported")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/characters/dasha_meshy/locomotion_v2/animation_report.json")) as Dictionary
	var distances_match: bool = manifest.has("clips")
	for key: String in DashaAnimation3D.CYCLE_DISTANCE:
		if not manifest.get("clips", {}).has(key) or absf(float(manifest.clips[key].get("cycle_distance", -1)) - float(DashaAnimation3D.CYCLE_DISTANCE[key])) > 0.00001:
			distances_match = false
	check(distances_match, "runtime cycle distances match authored foot support")
	var skeleton: Skeleton3D = actor.visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	check(skeleton.get_bone_count() == 31, "original 31 bone skin retained")
	actor.set_physics_process(false)
	for key: String in motion.clips:
		var clip: Animation = motion.player.get_animation(motion.clips[key])
		check(clip.loop_mode == Animation.LOOP_LINEAR and clip.length >= 0.75, key + " loops")
		if key == "walk":
			for track: int in clip.get_track_count():
				if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and ("foot.L" in str(clip.track_get_path(track)) or "shin.L" in str(clip.track_get_path(track)) or "thigh.L" in str(clip.track_get_path(track))):
					print("WALK_IMPORT_ROTATION_TRACK ", clip.track_get_path(track), " keys=", clip.track_get_key_count(track))
		motion.player.play(motion.clips[key], 0)
		motion.player.seek(0, true)
		var first: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("thigh.L" if key != "idle" else "spine"))
		motion.player.seek(clip.length * 0.25, true)
		var next: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("thigh.L" if key != "idle" else "spine"))
		check(first.angle_to(next) > 0.002, key + " changes imported bone pose")
		if key == "walk" or key == "run":
			# Test the actual global foot orientation, not only a local ankle
			# rotation induced by the shin. The previous swing held the boot flat.
			var ankle: int = skeleton.find_bone("foot.L")
			motion.player.seek(clip.length * (0.30 if key == "walk" else 0.20), true)
			var planted: Quaternion = skeleton.get_bone_global_pose(ankle).basis.orthonormalized().get_rotation_quaternion()
			motion.player.seek(clip.length * (0.6884 if key == "walk" else 0.52), true)
			var trailing: Quaternion = skeleton.get_bone_global_pose(ankle).basis.orthonormalized().get_rotation_quaternion()
			var flexion: float = rad_to_deg(planted.angle_to(trailing))
			print("ANKLE_GODOT ", key, " planted_to_trailing_pitch_deg=", flexion)
			check(flexion > (25.0 if key == "walk" else 35.0), key + " imports visible trailing ankle flexion")
	motion.state = ""
	actor.set_physics_process(true)
	for mode: String in ["walk", "run", "sneak"]:
		actor.position = Vector3(-8, 4.25, 3)
		actor.velocity = Vector3.ZERO
		actor.previous_input = Vector2.ZERO
		host._update_camera(true)
		if mode != "walk": Input.action_press(mode)
		Input.action_press("move_up")
		for i: int in 25: await physics_frame
		check(motion.state == mode and motion.player.is_playing(), "real input selects " + mode)
		check(motion.playback_rate > 0.1 and motion.playback_rate < 3, mode + " cadence follows actual displacement")
		var horizontal_speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
		check(absf(horizontal_speed - float(ApartmentPlayer3D.MOVE_SPEED[mode])) < 0.25, mode + " uses natural gait speed")
		Input.action_release("move_up")
		if mode != "walk": Input.action_release(mode)
		for i: int in 25: await physics_frame
		check(motion.state == "idle", mode + " returns to idle after stopping")
	# Exercise real ramp collisions, not just a manually supplied slope flag.
	for ascent: bool in [true, false]:
		actor.position = Vector3(-14, 0.3, -3.7) if ascent else Vector3(-14, 3.85, 4)
		actor.velocity = Vector3.ZERO
		actor.previous_input = Vector2.ZERO
		for i: int in 15: await physics_frame
		host._update_camera(true)
		press_direction(host, Vector3.BACK if ascent else Vector3.FORWARD)
		var start_height: float = actor.position.y
		# Slower authored stairs need a full second to leave the landing and
		# establish persistent ramp motion; this also exercises hysteresis.
		for i: int in 60: await physics_frame
		if motion.state != ("stairs_up" if ascent else "stairs_down") or absf(actor.position.y - start_height) <= 0.2:
			print("RAMP DEBUG ascent=", ascent, " state=", motion.state, " rise=", actor.position.y - start_height, " position=", actor.position)
		check(motion.state == ("stairs_up" if ascent else "stairs_down") and absf(actor.position.y - start_height) > 0.2, "physical ramp " + ("ascent" if ascent else "descent") + " animates")
		check(Vector2(actor.velocity.x, actor.velocity.z).length() <= 1.08, "walking slope limits cadence " + ("up" if ascent else "down"))
		release_directions()
	actor.position = Vector3(-11.6, 4.25, -6.6)
	actor.velocity = Vector3.ZERO
	actor.previous_input = Vector2.ZERO
	for i: int in 15: await physics_frame
	host._update_camera(true)
	press_direction(host, Vector3.LEFT)
	for i: int in 45: await physics_frame
	var emissions: int = actor.step_emissions
	for i: int in 20: await physics_frame
	check(motion.state == "idle" and actor.step_emissions == emissions, "holding input against actual wall stops gait and steps")
	release_directions()
	motion.update(0.016, Vector3(0.02,0,0), true, "walk", false)
	host.ui.open("test", "Animation dialogue lock")
	for i: int in 3: await process_frame
	check(not actor.is_physics_processing() and motion.state == "idle", "modal UI disables movement and settles to idle")
	host.ui.close()
	# Same running gait keeps its phase when switching mode, and at zero travel
	# freezes its gait clock even if the desired velocity remains nonzero.
	actor.set_physics_process(false)
	motion.update(0.016, Vector3(0.02,0,0), true, "walk", false)
	var phase: float = motion.phase
	motion.update(0.016, Vector3(0.02,0,0), true, "run", false)
	check(absf(motion.phase - phase - 0.02 / 2.2) < 0.001, "mode switch preserves foot phase")
	phase = motion.phase
	var contacts: int = motion.update(0.016, Vector3.ZERO, true, "run", false)
	check(motion.state == "idle" and is_equal_approx(phase, motion.phase) and contacts == 0, "zero travel stops gait and foot contacts")
	motion.phase = 0.8
	motion.update(0.016, Vector3(0.02,0,0), true, "walk", false)
	check(absf(motion.phase - DashaAnimation3D.START_PHASE - 0.02 / float(DashaAnimation3D.CYCLE_DISTANCE.walk)) < 0.001, "fresh movement starts from passing phase")
	for i: int in 9: motion.update(0.016, Vector3(0,0.01,0.02), true, "walk", true)
	check(motion.state == "stairs_up", "ramp ascent selects stairs up")
	motion.update(0.016, Vector3(0,-0.01,0.02), true, "walk", true)
	check(motion.state == "stairs_up", "one-frame slope noise does not flip gait")
	for i: int in 9: motion.update(0.016, Vector3(0,-0.01,0.02), true, "walk", true)
	check(motion.state == "stairs_down", "ramp descent selects stairs down")
	var thigh_index: int = skeleton.find_bone("thigh.L")
	var before_stop: Quaternion = skeleton.get_bone_pose_rotation(thigh_index)
	motion.update(0.016, Vector3.ZERO, true, "walk", false)
	check(before_stop.angle_to(skeleton.get_bone_pose_rotation(thigh_index)) < 0.15, "stop crossfade has no one-frame leg pop")
	motion.update(0.016, Vector3(0,-4,0), true, "walk", false)
	check(motion.state == "idle", "floor load does not become stair descent")
	contacts = motion.update(0.016, Vector3(10,0,0), true, "run", false)
	check(motion.state == "idle" and contacts == 0, "teleport has no footstep burst")
	motion.update(0.016, Vector3(0.02,0,0), true, "run", false, true)
	check(motion.state == "idle", "control lock selects idle")
	print("DASHA ANIMATION: ", passed, " passed, ", failed, " failed")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)

func press_direction(host: Node, direction: Vector3) -> void:
	var screen: Vector2 = (host.camera.unproject_position(host.player.position + direction) - host.camera.unproject_position(host.player.position)).normalized()
	Input.action_press("move_right" if screen.x > 0 else "move_left", absf(screen.x))
	Input.action_press("move_down" if screen.y > 0 else "move_up", absf(screen.y))

func release_directions() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
