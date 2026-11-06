extends SceneTree

# Real Forward+ gameplay capture. Run with an isolated APPDATA profile:
# godot --path <project> --fixed-fps 30 --resolution 1280x720 --rendering-method forward_plus
#   --script res://AI/review/capture_dasha_motion.gd
# Outputs the native 640x360 3D viewport, not a Blender/model-only render.
const FRAME_COUNT: int = 48
const OUTPUT: String = "res://.godot/dasha-motion-review/game"
var host: Node
var records: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	host = load("res://scenes/chapter_1_3d/apartment.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	await process_frame
	host.skip_intro()
	host.ui.close()
	while not host.navigation_ready: await physics_frame
	for i: int in 15: await physics_frame
	var actor: ApartmentPlayer3D = host.player
	actor.position = Vector3(-8, 4.25, 4)
	actor.velocity = Vector3.ZERO
	actor.previous_input = Vector2.ZERO
	actor.held_direction = Vector3.ZERO
	host._update_camera(true)
	var close_camera: bool = "--close-camera" in OS.get_cmdline_user_args()
	if close_camera:
		host.camera.position = actor.position + Vector3(4.0, 4.0, -4.0)
		host.camera.look_at(actor.position + Vector3.UP)
	# Keep the authored gallery composition fixed for the comparison. Player
	# physics/input/animations and world collision remain the normal game code.
	host.set_process(false)
	for i: int in 45:
		await physics_frame
		host.world.update_visibility(actor.position, host.camera, host.room_id, 1.0 / 60.0)
	var folder: String = ProjectSettings.globalize_path(OUTPUT + ("_close" if close_camera else ""))
	DirAccess.make_dir_recursive_absolute(folder)
	var start: Vector3 = actor.position
	for frame: int in FRAME_COUNT:
		if frame == 0:
			Input.action_press("move_up")
		elif frame == 18:
			Input.action_release("move_up")
		elif frame == 26:
			Input.action_press("run")
			Input.action_press("move_up")
		elif frame == 38:
			Input.action_release("move_up")
			Input.action_press("move_right")
		# --fixed-fps 30 yields two 60Hz physics ticks before each drawn frame.
		# Save the engine tick index as evidence of the actual sample interval.
		await process_frame
		host.world.update_visibility(actor.position, host.camera, host.room_id, 1.0 / 30.0)
		host.listener.position = actor.position + Vector3.UP * 1.5
		await RenderingServer.frame_post_draw
		var image: Image = host.viewport_3d.get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(folder.path_join("%03d.png" % frame)) != OK:
			push_error("Failed to save gameplay motion frame %d" % frame)
			quit(1)
			return
		records.append({"frame":frame, "stage":"walk" if frame < 18 else ("stop" if frame < 26 else ("run" if frame < 38 else "turn")),
			"state":actor.locomotion.state, "phase":actor.locomotion.phase, "physics_tick":Engine.get_physics_frames(),
			"position":[actor.position.x,actor.position.y,actor.position.z],
			"yaw":actor.visual.rotation.y, "footsteps":actor.step_emissions})
	for action: String in ["move_left","move_right","move_up","move_down","run","sneak"]:
		Input.action_release(action)
	var manifest: Dictionary = {"renderer":"Forward+", "source":"actual apartment gameplay / fixed gallery review camera" if close_camera else "actual apartment gameplay / fixed authored gallery camera",
		"size":[640,360], "nominal_fps":30, "frames":records,
		"travel":actor.position.distance_to(start)}
	var file: FileAccess = FileAccess.open(folder.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write gameplay motion manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("DASHA_GAMEPLAY_CAPTURE ", FRAME_COUNT, " frames at ", folder, " travel=", manifest.travel)
	host.queue_free()
	await process_frame
	quit(0)
