extends SceneTree
var failures: int = 0
var game: Node2D
const OUT: String = "E:/kamdraaa-game/docs/review/images/november/"
func _initialize() -> void: call_deferred("run")
func check(title: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	check(name_value + " capture", root.get_texture().get_image().save_png(OUT + name_value + ".png") == OK)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-"):
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/chapter_1/apartment.tscn")
	await process_frame
	await process_frame
	game = current_scene
	await shot("01-opening")
	var first: Image = root.get_texture().get_image()
	check("opening covers location", first.get_pixel(160,250).get_luminance() < 0.08 and first.get_pixel(1000,300).get_luminance() < 0.08 and first.get_pixel(160,250).is_equal_approx(first.get_pixel(1000,300)))
	check("skip available", is_instance_valid(game.ui.intro_skip_button))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = game.ui.intro_skip_button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click.pressed = false
	root.push_input(click)
	await process_frame
	await process_frame
	await process_frame
	check("skip restores gameplay and tutorial", not game.intro_active and game.state.has("opening_done") and game.ui.modal_kind.is_empty() and not game.player.is_control_locked)
	check("skip preserves pill lesson", not game.state.has("dose") and root.get_node("ParanoiaManager").get_paranoia() >= 99)
	game.ui._process(0)
	check("goal popup appears", game.ui.goal_notice.visible and game.ui.goal_notice_text.text.contains(game.current_goal()))
	game.ui.goal_notice_time = 1
	game.ui._process(0)
	check("same goal does not repeat", game.ui.goal_notice_time == 1)
	Input.action_press("run")
	game._process(0)
	check("run speed", game.player.speed == 325 and game.player.movement_mode == "run")
	Input.action_press("sneak")
	game._process(0)
	check("sneak takes priority", game.player.speed == 90 and game.player.movement_mode == "sneak")
	Input.action_release("sneak")
	Input.action_release("run")
	game._process(0)
	check("walk restored", game.player.speed == 205 and game.player.movement_mode == "walk")
	game.set_process(false)
	game.player.set_physics_process(false)
	for mode: String in ["sneak", "walk", "run"]:
		game.player.movement_mode = mode
		game.player.velocity = Vector2(160,0)
		game.player._walk_distance = 42
		game.player._update_sprite_animation(0.1)
		await shot("02-" + mode)
	game.player.position = ApartmentWorld.iso(Vector2(1240,280))
	game.player.get_node("Camera2D").reset_smoothing()
	game.world.update_lighting(game.player.position,Vector2.UP,true,true)
	await create_timer(0.4).timeout
	await shot("03-bathroom")
	game.player.position = ApartmentWorld.iso(Vector2(1300,428))
	game.player.get_node("Camera2D").reset_smoothing()
	game.world.update_lighting(game.player.position,Vector2.DOWN,true,true)
	await create_timer(0.3).timeout
	await shot("04-wall-circle")
	check("no continuous rain or hum", game.get_node("Atmosphere").hum == null)
	check("wall alpha is local shader mask", game.world.wall_materials[0].shader.code.contains("visibility_alpha"))
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(256,256)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for x: int in [0,128]:
		var face: Polygon2D = Polygon2D.new()
		face.polygon = PackedVector2Array([Vector2(x,100),Vector2(x+128,100),Vector2(x+128,200),Vector2(x,200)])
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = preload("res://shaders/apartment_wall.gdshader")
		mat.set_shader_parameter("wall_start",Vector2(x,200))
		mat.set_shader_parameter("wall_end",Vector2(x+128,200))
		mat.set_shader_parameter("torch_position",Vector2(128,180))
		face.material = mat
		view.add_child(face)
	await process_frame
	await RenderingServer.frame_post_draw
	var mask: Image = view.get_texture().get_image()
	var center: float = mask.get_pixel(128,140).a
	var middle: float = mask.get_pixel(200,140).a
	var edge: float = mask.get_pixel(245,140).a
	mask.save_png(OUT + "05-wall-mask.png")
	check("wall circle has smooth alpha falloff", center < 0.12 and middle > center + 0.15 and edge > 0.98)
	check("wall circle continuous across segments", absf(mask.get_pixel(127,140).a-center) < 0.02)
	view.queue_free()
	print("NOVEMBER_CHECK failures=", failures)
	quit(0 if failures == 0 else 1)
