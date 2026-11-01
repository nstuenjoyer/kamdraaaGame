extends SceneTree

const OUTPUT_DIR: String = "res://docs/review/images"

func _initialize() -> void:
	call_deferred("capture")

func save_frame(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(OUTPUT_DIR + "/" + filename)
	if result != OK:
		push_error("Capture failed: " + filename)
		quit(1)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var camera: Camera2D = current_scene.get_node("Player/Camera2D")
	camera.position_smoothing_enabled = false
	camera.top_level = true
	camera.position = Vector2(780, 400)
	camera.zoom = Vector2(0.95, 0.95)
	await create_timer(1.0).timeout
	await save_frame("closed.png")
	current_scene.get_node("Door").open()
	await create_timer(0.6).timeout
	await save_frame("open.png")
	current_scene.get_node("Player").position = Vector2(1100, 520)
	current_scene.get_node("Player/Flashlight").toggle_flashlight(false)
	await create_timer(0.5).timeout
	await save_frame("dark.png")
	current_scene.get_node("Player/Flashlight").toggle_flashlight(true)
	await create_timer(0.5).timeout
	await save_frame("flashlight.png")
	var window: Node2D = current_scene.get_node("Window")
	window.set_process(false)
	window.car_timer.stop()
	current_scene.get_node("Player/Flashlight").toggle_flashlight(false)
	camera.position = Vector2(510, 340)
	camera.zoom = Vector2(1.4, 1.4)
	window.neon_light.energy = 1.0
	window.neon_light.color = Color(0.15, 0.85, 1.0)
	await create_timer(0.2).timeout
	await save_frame("window-neon.png")
	window.neon_light.enabled = false
	window._is_car_passing = true
	window.car_light.enabled = true
	for phase: float in [0.25, 0.5, 0.75]:
		window._car_progress = phase
		window._update_car_pass(0.0)
		await create_timer(0.2).timeout
		await save_frame("window-car-%d.png" % int(phase * 100.0))
	print("CAPTURE_PASS")
	quit()
