extends SceneTree

const SIZE: Vector2i = Vector2i(1672,941)
const OUT: String = "E:/kamdraaa-game/docs/review/images/window-mask/"
const OUTSIDE: Array[Vector2i] = [Vector2i(500,300),Vector2i(970,300),Vector2i(1250,300),Vector2i(1270,500),Vector2i(1540,300),Vector2i(1550,450),Vector2i(1560,650),Vector2i(1000,610),Vector2i(1100,618),Vector2i(1200,647),Vector2i(1320,675),Vector2i(1430,690),Vector2i(1525,700),Vector2i(1080,113),Vector2i(1170,98),Vector2i(1350,78),Vector2i(1450,59)]
const INSIDE: Array[Vector2i] = [Vector2i(1100,30),Vector2i(1190,30),Vector2i(1050,200),Vector2i(1180,500),Vector2i(1380,15),Vector2i(1350,200),Vector2i(1480,600)]
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(title: String, ok: bool) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func flood(shader_path: String, restricted: bool) -> Image:
	var view: SubViewport = SubViewport.new()
	view.size = SIZE
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var water: MultiMeshInstance2D = MultiMeshInstance2D.new()
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(20,20)
	instances.mesh = mesh
	var columns: int = ceili(float(SIZE.x)/12.0)
	var rows: int = ceili(float(SIZE.y)/12.0)
	instances.instance_count = columns*rows
	for y: int in rows:
		for x: int in columns:
			var index: int = y*columns+x
			instances.set_instance_transform_2d(index,Transform2D(0,Vector2(x*12+6,y*12+6)))
			instances.set_instance_custom_data(index,Color(1,0,0,1))
	water.multimesh = instances
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(shader_path)
	material.set_shader_parameter("window_mask_enabled",restricted)
	water.material = material
	view.add_child(water)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = view.get_texture().get_image()
	view.queue_free()
	await process_frame
	return picture

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-"):
		push_error("Use isolated APPDATA under .godot/chapter-check-*")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	for pass_name: String in ["drop","trail"]:
		var path: String = "res://shaders/glass_"+pass_name+".gdshader"
		var unmasked: Image = await flood(path,false)
		var masked: Image = await flood(path,true)
		check(pass_name+" capture",masked.save_png(OUT+pass_name+"-flood.png") == OK)
		for point: Vector2i in OUTSIDE:
			check(pass_name+" stencil covers test location "+str(point),unmasked.get_pixelv(point).a > 0.02)
			check(pass_name+" no water outside glass "+str(point),masked.get_pixelv(point).a < 0.001)
		for point: Vector2i in INSIDE:
			check(pass_name+" water survives on glass "+str(point),masked.get_pixelv(point).a > 0.02)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	check("main menu capture",root.get_texture().get_image().save_png(OUT+"menu.png") == OK)
	print("WINDOW_MASK_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
