extends SceneTree

var failures: int = 0
var checks: int = 0
var viewport: SubViewport
var material: ShaderMaterial
const OUTPUT: String = "E:/kamdraaa-game/AI/review/images/hand-light/"

func _initialize() -> void: call_deferred("run")

func check(title: String, ok: bool) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func image_at(height: float, enabled: bool, blocked: bool = false, barrier_height: float = 0.0) -> Image:
	material.set_shader_parameter("torch_position", Vector2(256,280))
	material.set_shader_parameter("torch_emission_position",Vector2(256,280-height))
	material.set_shader_parameter("torch_height",height)
	material.set_shader_parameter("torch_on",enabled)
	material.set_shader_parameter("barrier_count",1 if blocked else 0)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(256)
	heights.fill(0.0)
	heights[0] = barrier_height
	material.set_shader_parameter("barrier_heights",heights)
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func luminance(picture: Image, height: int, x: int = 256) -> float:
	var sum: float = 0.0
	for y: int in range(220-height-2,220-height+3):
		for px: int in range(x-2,x+3): sum += picture.get_pixel(px,y).get_luminance()
	return sum/25.0

func native_shadow_check() -> void:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(512,320)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var floor_face: Polygon2D = Polygon2D.new()
	floor_face.polygon = PackedVector2Array([Vector2.ZERO,Vector2(512,0),Vector2(512,320),Vector2(0,320)])
	view.add_child(floor_face)
	var dim: CanvasModulate = CanvasModulate.new()
	dim.color = Color(0.03,0.03,0.03)
	view.add_child(dim)
	var image: Image = Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 128:
			var delta: Vector2 = Vector2(x-64,y-64)
			var strength: float = maxf(0,1.0-delta.length()/60.0)
			if delta.x < 0 or absf(delta.y) > delta.x*0.8: strength = 0
			image.set_pixel(x,y,Color(1,1,1,strength))
	var light: PointLight2D = PointLight2D.new()
	light.texture = ImageTexture.create_from_image(image)
	light.texture_scale = 4
	light.position = Vector2(200,220)
	light.offset = Vector2(0,-58)
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	view.add_child(light)
	await process_frame
	await RenderingServer.frame_post_draw
	var open: Image = view.get_texture().get_image()
	var obstacle: LightOccluder2D = LightOccluder2D.new()
	var shape: OccluderPolygon2D = OccluderPolygon2D.new()
	shape.closed = false
	shape.polygon = PackedVector2Array([Vector2(270,200),Vector2(270,240)])
	obstacle.occluder = shape
	view.add_child(obstacle)
	await process_frame
	await RenderingServer.frame_post_draw
	var shaded: Image = view.get_texture().get_image()
	var before: float = open.get_pixel(340,220).get_luminance()
	var after: float = shaded.get_pixel(340,220).get_luminance()
	print("NATIVE_OFFSET clear=",before," blocked=",after," raised=",open.get_pixel(220,162).get_luminance()," feet=",open.get_pixel(220,220).get_luminance())
	check("native texture offset raises cone origin to lamp height",open.get_pixel(220,162).get_luminance() > open.get_pixel(220,220).get_luminance()+0.15)
	check("native PointLight texture offset retains ground shadow origin",before > 0.15 and after < before*0.35)
	check("ground shadow does not wrongly block above barrier",shaded.get_pixel(340,130).get_luminance() > 0.15)
	check("native light capture",shaded.save_png(OUTPUT+"native-shadow-offset.png") == OK)
	light.rotation = PI*0.5
	light.offset = Vector2(0,-58).rotated(-light.rotation)
	await process_frame
	await RenderingServer.frame_post_draw
	var turned: Image = view.get_texture().get_image()
	check("rotated local offset keeps the lens at world hand height",turned.get_pixel(200,180).get_luminance() > 0.5 and turned.get_pixel(258,220).get_luminance() < 0.08)
	view.queue_free()

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/chapter-check-"):
		push_error("Isolate APPDATA under .godot/chapter-check-*")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(512,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/apartment_wall.gdshader")
	material.set_shader_parameter("wall_start",Vector2(0,220))
	material.set_shader_parameter("wall_end",Vector2(512,220))
	material.set_shader_parameter("torch_direction",Vector2.UP)
	material.set_shader_parameter("player_position",Vector2(-500,-500))
	material.set_shader_parameter("barriers",PackedVector4Array([Vector4(0,250,512,250)]))
	for x: int in [0,256]:
		var wall: Polygon2D = Polygon2D.new()
		wall.polygon = PackedVector2Array([Vector2(x,20),Vector2(x+256,20),Vector2(x+256,220),Vector2(x,220)])
		wall.color = Color("8e9aab")
		wall.material = material
		viewport.add_child(wall)
	var off: Image = await image_at(58,false)
	var standing: Image = await image_at(58,true)
	var low: Image = await image_at(28,true)
	var blocked: Image = await image_at(58,true,true)
	print("HAND_GAINS ",luminance(standing,58)-luminance(off,58)," ",luminance(standing,5)-luminance(off,5)," SEAM ",luminance(standing,58,252)," ",luminance(standing,58,260))
	check("standing wall spot starts at hand height",luminance(standing,58) > luminance(off,58)+0.1)
	check("near wall floor receives only spill below the hand spot",luminance(standing,5)-luminance(off,5) < (luminance(standing,58)-luminance(off,58))*0.2)
	check("lowering hand lowers the wall spot",luminance(low,28) > luminance(standing,28)+0.06)
	check("upper spot responds to standing versus crouched height",luminance(standing,58) > luminance(low,58)+0.06)
	check("ground barrier still blocks raised hand beam",absf(luminance(blocked,58)-luminance(off,58)) < 0.01)
	check("continuous cone across wall sections",absf(luminance(standing,58,252)-luminance(standing,58,260)) < 0.035)
	check("standing capture",standing.save_png(OUTPUT+"wall-standing.png") == OK)
	check("crouched capture",low.save_png(OUTPUT+"wall-crouched.png") == OK)
	check("occlusion capture",blocked.save_png(OUTPUT+"wall-blocked.png") == OK)
	var low_prop: Image = await image_at(58,true,true,40)
	var tall_prop: Image = await image_at(58,true,true,80)
	var crouch_off: Image = await image_at(28,false)
	var crouch_prop: Image = await image_at(28,true,true,40)
	check("standing hand shines over a low prop onto the wall",absf(luminance(low_prop,58)-luminance(standing,58)) < 0.01)
	check("tall prop still blocks the raised wall spot",absf(luminance(tall_prop,58)-luminance(off,58)) < 0.01)
	check("zero or unknown barrier height remains an opaque wall",absf(luminance(blocked,58)-luminance(off,58)) < 0.01)
	check("same low prop blocks the crouched hand below its top",absf(luminance(crouch_prop,28)-luminance(crouch_off,28)) < 0.01)
	check("low prop wall-light capture",low_prop.save_png(OUTPUT+"wall-over-low-prop.png") == OK)
	# Validate the apartment API without building a world or changing player data.
	var world: ApartmentWorld = ApartmentWorld.new()
	world.wall_materials.append(material)
	root.add_child(world)
	world.update_lighting(Vector2(200,300),Vector2.RIGHT,true,false,Vector2(215,242),58)
	check("wall API projects the raised lens onto floor for barriers",material.get_shader_parameter("torch_position") == Vector2(215,300))
	check("visibility circle remains centered on player independently",material.get_shader_parameter("player_position") == Vector2(200,300))
	check("wall API preserves actual emitter position",material.get_shader_parameter("torch_emission_position") == Vector2(215,242))
	world.walls.append(Vector4(207,250,207,350))
	world.update_lighting(Vector2(200,300),Vector2.RIGHT,true,false,Vector2(215,242),58)
	check("hand cannot push shadow origin through a wall",material.get_shader_parameter("torch_position") == Vector2(200,300))
	world.update_lighting(Vector2(200,300),Vector2.RIGHT,true,false)
	check("four argument API retains default hand height",material.get_shader_parameter("torch_height") == 58.0 and material.get_shader_parameter("torch_position") == Vector2(200,300))
	await native_shadow_check()
	print("HAND_WALL_LIGHT_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
