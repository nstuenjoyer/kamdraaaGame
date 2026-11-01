extends SceneTree

var game: Node2D
var failures: int = 0
var output_directory: String

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> Image:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	check("capture " + filename, picture.save_png(output_directory.path_join(filename + ".png")) == OK)
	print("CAPTURE ", filename)
	return picture

func sample(picture: Image, world_point: Vector2) -> float:
	var pixel: Vector2i = Vector2i(game.world.get_global_transform_with_canvas() * world_point)
	var total: float = 0.0
	for y: int in range(pixel.y - 3, pixel.y + 4):
		for x: int in range(pixel.x - 3, pixel.x + 4):
			var color: Color = picture.get_pixel(x, y)
			total += color.get_luminance()
	return total / 49.0

func place(pos: Vector2, direction: Vector2, zoom: float = 1.05) -> void:
	game.ui.close()
	game.player.position = ApartmentWorld.iso(pos)
	game.player.velocity = Vector2.ZERO
	game.flashlight.rotation = direction.angle()
	game.player.get_node("Camera2D").zoom = Vector2(zoom, zoom)
	game.player.get_node("Camera2D").reset_smoothing()
	game.flashlight._process(0.0)
	game.world.update_lighting(game.player.position, direction, game.flashlight.is_emitting(), game.state.has("power"),game.flashlight.emission_position(),game.flashlight.emission_height())
	game._update_target()
	game.ui._process(0.0)

func check(title: String, value: bool) -> void:
	print(("PASS " if value else "FAIL ") + title)
	if not value: failures += 1

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().contains("/.godot/chapter-check-"):
		push_error("Use tools/run_chapter_checks.ps1 -Visual to isolate saves/settings")
		quit(1)
		return
	output_directory = OS.get_environment("KAMDRAAA_CHAPTER_CAPTURE_DIR")
	if output_directory.is_empty():
		output_directory = ProjectSettings.globalize_path("res://AI/review/images/chapter_1/")
	DirAccess.make_dir_recursive_absolute(output_directory)
	print("CAPTURE_DIRECTORY ",output_directory)
	change_scene_to_file(ApartmentState.SCENE)
	await process_frame
	await process_frame
	await create_timer(1.65).timeout
	game = current_scene
	await capture("00-opening")
	while game.intro_active: await process_frame
	await capture("01-intro")
	game.ui.close()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.flashlight.set_process(false)
	place(Vector2(370, 320), Vector2.UP)
	await capture("02-bedroom-dark")
	game._update_target()
	game.ui._process(0.0)
	await capture("02b-context-action")
	var inventory: Node = root.get_node("InventoryManager")
	inventory.add_item("pills", "Седативное", 2, "", "Снижает стресс на 40 пунктов. Тревога сама не проходит.", true)
	inventory.add_item("front_key", "Входной ключ", 1, "", "Открывает дверь в прихожей.")
	inventory.add_item("flashlight", "Фонарик", 1, "", "Свет останавливает страх темноты.")
	game.ui.inventory()
	await capture("02c-inventory")
	game.ui.close()
	for pose: Array in [["bed-right", Vector2(320, 250)], ["bed-front", Vector2(200, 430)], ["bed-left", Vector2(42, 250)], ["bed-back", Vector2(200, 52)]]:
		place(pose[1], Vector2.RIGHT)
		await capture("02d-" + pose[0])
	game.state.mark("dose")
	game.state.mark("bed")
	game.state.mark("pills")
	game.state.mark("flashlight")
	game.state.mark("study_unlocked")
	game._refresh_world()
	game.flashlight.toggle_flashlight(true, true)
	for test: Array in [["north-wall", Vector2(470, 250), Vector2(470, 0)], ["east-wall", Vector2(760, 840), Vector2(1000, 810)], ["bath-wall", Vector2(1240, 300), Vector2(1400, 450)], ["south-wall", Vector2(330, 1320), Vector2(330, 1500)]]:
		var pos: Vector2 = test[1]
		var wall_point: Vector2 = ApartmentWorld.iso(test[2])
		var direction: Vector2 = (wall_point - ApartmentWorld.iso(pos)).normalized()
		place(pos, -direction)
		var away: Image = await capture("03-" + test[0] + "-away")
		place(pos, direction)
		var aimed: Image = await capture("03-" + test[0] + "-aimed")
		var target: Vector2 = wall_point - Vector2(0, 35)
		var before: float = sample(away, target)
		var after: float = sample(aimed, target)
		print("WALL ", test[0], " away=", before, " aimed=", after)
		check("flashlight lights " + test[0], after > before + 0.035)
		if test[0] == "east-wall":
			var behind: Vector2 = ApartmentWorld.iso(Vector2(1100, 810))
			check("floor behind partition stays dark", absf(sample(aimed, behind) - sample(away, behind)) < 0.025)
	place(Vector2(570, 800), Vector2.RIGHT)
	await capture("03-player-at-foreground-wall")
	var faded: bool = true
	for material: ShaderMaterial in game.world.wall_materials:
		if not (material.get_shader_parameter("player_position") as Vector2).is_equal_approx(game.player.position): faded = false
	check("wall visibility circle follows player on every segment", faded)
	game.state.mark("power")
	game._refresh_world()
	game.flashlight.toggle_flashlight(false, true)
	place(Vector2(1200, 690), Vector2.RIGHT)
	await capture("04-storage-powered")
	place(Vector2(780, 1180), Vector2.RIGHT, 0.28)
	await capture("05-apartment-overview")
	for room: Array in [["09-study", Vector2(320, 2100)], ["10-utility", Vector2(1280, 2080)], ["11-living", Vector2(470, 1190)], ["12-kitchen", Vector2(1350, 1140)]]:
		place(room[1], Vector2.RIGHT, 0.92)
		await capture(room[0])
	game.story.pin_panel()
	await capture("13-cabinet-puzzle")
	game.ui.journal("route")
	await capture("14-investigation-log")
	game.ui.close()
	game.read_document("diary")
	await capture("06-diary")
	game.ui.journal()
	await capture("06-tasks")
	game.ui.pause()
	await capture("06-pause")
	game.ui.close()
	game.ui.apartment_map()
	await capture("06-map")
	game.ui.close()
	game.ui.begin_qte()
	await capture("07-qte")
	game.ui.close()
	game.state.mark("coat")
	game.state.mark("front_key")
	game.choose_diary("trust")
	game.state.phase = "coat_done"
	game.begin_encounter()
	game.ui.close()
	place(Vector2(800, 280), Vector2.UP)
	game.enemy.set_physics_process(false)
	await capture("08-encounter")
	var began: int = Time.get_ticks_usec()
	for i: int in 120:
		await process_frame
		await RenderingServer.frame_post_draw
	print("RENDER_FRAME_WALL_MS ", float(Time.get_ticks_usec() - began) / 120000.0, " FPS ", Engine.get_frames_per_second())
	print("CHAPTER_VISUAL failures=", failures)
	quit(1 if failures else 0)
