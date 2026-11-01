extends SceneTree

const OUTPUT_DIR: String = "res://AI/review/images/lighting"
var failures: int = 0
var _room: Node2D
var _player: CharacterBody2D
var _flashlight: Node2D
var _camera: Camera2D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func frame(filename: String) -> Image:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check("capture " + filename, image.save_png(OUTPUT_DIR + "/" + filename) == OK)
	return image

func luminance_at(image: Image, world_point: Vector2) -> float:
	var pixel: Vector2i = Vector2i(_room.get_global_transform_with_canvas() * world_point)
	var luminance: float = 0.0
	for y: int in range(pixel.y - 2, pixel.y + 3):
		for x: int in range(pixel.x - 2, pixel.x + 3):
			var color: Color = image.get_pixel(x, y)
			luminance += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return luminance / 25.0

func place(position: Vector2, aim: float, camera_position: Vector2, zoom: float) -> void:
	_player.position = position
	_flashlight.rotation = aim
	_camera.position = camera_position
	_camera.zoom = Vector2(zoom, zoom)
	_camera.reset_smoothing()

func wall_spot_case(label: String, position: Vector2, wall_foot: Vector2, camera_position: Vector2) -> void:
	var direction: float = (wall_foot - position).angle()
	place(position, direction + PI, camera_position, 1.45)
	var away: Image = await frame(label + "-away.png")
	var sample: Vector2 = wall_foot - Vector2(0, 45)
	var baseline: float = luminance_at(away, sample)
	_flashlight.rotation = direction
	var aimed: Image = await frame(label + "-aimed.png")
	var brightness: float = luminance_at(aimed, sample)
	print("WALL_LUMINANCE ", label, " away=", baseline, " aimed=", brightness)
	check("directional flashlight reaches " + label, brightness > baseline + 0.035)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	_room = current_scene as Node2D
	_player = _room.get_node("Player") as CharacterBody2D
	_player.set_physics_process(false)
	_flashlight = _player.get_node("Flashlight") as Node2D
	_flashlight.set_process(false)
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.position_smoothing_enabled = false
	_camera.top_level = true
	var window: Node2D = _room.get_node("Window") as Node2D
	window.set_process(false)
	window.car_timer.stop()
	window.neon_light.energy = 0.8
	place(Vector2(480, 290), 0.0, Vector2(780, 400), 0.95)
	var bedroom: Image = await frame("bedroom.png")
	check("back wall face is readable", luminance_at(bedroom, Vector2(760, 190)) > 0.06)
	var closed_door_sample: Vector2 = Vector2(900, 510)
	var closed_luminance: float = luminance_at(bedroom, closed_door_sample)
	_room.get_node("RoomLights/Room1CeilingLight").enabled = false
	var isolated: Image = await frame("closed-ceiling-off.png")
	check("bedroom ceiling does not leak through closed door", absf(luminance_at(isolated, closed_door_sample) - closed_luminance) < 0.015)
	_room.get_node("RoomLights/Room1CeilingLight").enabled = true
	_room.get_node("Door").open()
	place(Vector2(850, 435), -PI / 2.0, Vector2(850, 420), 1.8)
	await frame("doorway.png")
	var faded_wall: Polygon2D = _room.get_node("Walls/DarkCorridorRight_Visual") as Polygon2D
	check("wall fades over character at doorway", faded_wall.color.a <= 0.11)
	check("character draws above foreground rim", _player.get_node("DashaSprite").z_index > _room.get_node("FrontWalls").z_index)
	place(Vector2(1100, 535), 0.0, Vector2(1100, 485), 1.35)
	_flashlight.toggle_flashlight(false)
	var dark: Image = await frame("storage-off.png")
	check("doorway wall restores after leaving", faded_wall.color.a >= 0.99)
	var sample_point: Vector2 = Vector2(1180, 535)
	var unlit: float = luminance_at(dark, sample_point)
	_flashlight.toggle_flashlight(true)
	var lit: Image = await frame("storage-on.png")
	var illuminated: float = luminance_at(lit, sample_point)
	print("STORAGE_LUMINANCE off=", unlit, " on=", illuminated)
	check("flashlight reveals storage floor", illuminated > unlit * 1.8 and illuminated > 0.12)
	for aim: float in [-PI / 2.0, PI, PI / 2.0]:
		_flashlight.rotation = aim
		await frame("storage-aim-%d.png" % int(rad_to_deg(aim)))
	place(Vector2(1180, 490), (Vector2(1230, 425) - Vector2(1180, 490)).angle(), Vector2(1140, 470), 1.5)
	await frame("storage-safe.png")
	place(Vector2(1140, 415), -PI / 2.0, Vector2(1140, 440), 1.6)
	await frame("storage-back-wall.png")
	await wall_spot_case("bedroom-nw", Vector2(480, 315), Vector2(480, 220), Vector2(500, 260))
	await wall_spot_case("bedroom-ne", Vector2(780, 300), Vector2(780, 250), Vector2(740, 260))
	await wall_spot_case("bedroom-right", Vector2(680, 330), Vector2(900, 370), Vector2(790, 320))
	place(Vector2(675, 450), (Vector2(600, 520) - Vector2(675, 450)).angle(), Vector2(650, 435), 2.0)
	await frame("lower-wall-corner.png")
	print("LIGHTING_RESULT failures=", failures)
	quit(1 if failures else 0)
