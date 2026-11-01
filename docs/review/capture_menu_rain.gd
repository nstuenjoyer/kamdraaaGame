extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var rain: Node2D = current_scene.get_node("RainOverlay/GlassRain") as Node2D
	rain.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/review/images/menu-rain")
	for seconds: int in [0, 5, 15, 30]:
		rain.simulation.initialize(104729)
		for frame: int in range(seconds * 60):
			rain.simulation.advance(1.0 / 60.0)
		rain._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/review/images/menu-rain/%02d.png" % seconds)
		print("MENU_RAIN_FRAME time=", seconds, " drops=", rain.simulation.drops.size(), " trails=", rain.simulation.trails.size())
	current_scene._on_settings_pressed()
	await create_timer(0.4).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/images/menu-rain/settings.png")
	print("MENU_RAIN_CAPTURE_PASS")
	current_scene._close_all_modals(true)
	current_scene.set_process(false)
	rain.simulation.initialize(104729)
	for frame: int in range(600):
		rain.simulation.advance(1.0 / 60.0)
	DirAccess.make_dir_recursive_absolute("res://.godot/rain-frames")
	for frame: int in range(120):
		for step: int in range(6):
			rain.simulation.advance(1.0 / 60.0)
		rain._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		image.save_png("res://.godot/rain-frames/%03d.png" % frame)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	rain._process(0.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/images/menu-rain/wide.png")
	print("MENU_RAIN_ANIMATION_PASS")
	quit()
