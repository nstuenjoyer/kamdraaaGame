extends SceneTree

# These checks target visible motion, not merely the light-to-lens attachment.
const DT: float = 1.0/60.0
var failures: int = 0
var checks: int = 0
var game: Node2D
var hand: HeldFlashlight
var scale_value: float
var output_directory: String
var frames_directory: String

func _initialize() -> void:
	call_deferred("run")

func check(label: String, result: bool) -> void:
	checks += 1
	print(("PASS " if result else "FAIL ")+label)
	if not result: failures += 1

func step(seconds: float = DT) -> void:
	game.flashlight._process(seconds)
	game.world.update_lighting(game.player.position,Vector2.RIGHT.rotated(game.flashlight.rotation),game.flashlight.is_emitting(),game.state.has("power"),game.flashlight.emission_position(),game.flashlight.emission_height())

func pose(facing: String, mirrored: bool, frame: int = 0) -> void:
	game.player.dasha_animation.crouch_amount = 0.0
	game.player.dasha_animation.show_pose("idle",frame,facing)
	game.player.sprite.flip_h = mirrored

func frame_capture(folder: String, index: int) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8) # Forward+ can return a different readback format.
	var center: Vector2i = Vector2i(game.world.get_global_transform_with_canvas()*game.player.global_position)
	var crop: Rect2i = Rect2i(center-Vector2i(180,320),Vector2i(360,370)).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
	var result: Image = picture.get_region(crop)
	if result.save_png(frames_directory.path_join(folder).path_join("%03d.png"%index)) != OK:
		failures += 1
	return result

func sheet(images: Array[Image], name_value: String, columns: int) -> void:
	if images.is_empty():
		check(name_value+" contact sheet",false)
		return
	var size: Vector2i = images[0].get_size()
	var picture: Image = Image.create(size.x*columns,size.y*ceili(float(images.size())/columns),false,Image.FORMAT_RGBA8)
	picture.fill(Color("16151a"))
	for index: int in images.size():
		picture.blit_rect(images[index],Rect2i(Vector2i.ZERO,size),Vector2i(index%columns,index/columns)*size)
	check(name_value+" contact sheet",picture.save_png(output_directory.path_join(name_value+".png")) == OK)

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/chapter-check-arm-motion-"):
		quit(1)
		return
	var project_root: String = OS.get_environment("KAMDRAAA_ARM_REVIEW_ROOT").replace("\\","/")
	if project_root.is_empty():
		quit(1)
		return
	output_directory = project_root.path_join("AI/review/images/arm-motion")
	frames_directory = project_root.path_join(".godot/arm-motion-frames")
	for folder: String in [output_directory,frames_directory.path_join("draw-stow"),frames_directory.path_join("sweep"),frames_directory.path_join("turn-draw")]:
		DirAccess.make_dir_recursive_absolute(folder)
	change_scene_to_file("res://scenes/chapter_1/apartment.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.skip_intro()
	await process_frame
	await process_frame
	await process_frame
	game.set_process(false)
	game.ui.close()
	game.ui.hud.visible = false
	game.player.set_physics_process(false)
	game.player.set_control_locked(false)
	game.player.position = ApartmentWorld.iso(Vector2(380,390))
	game.player.get_node("Camera2D").zoom = Vector2(2.3,2.3)
	game.player.get_node("Camera2D").reset_smoothing()
	game.state.mark("flashlight")
	game._refresh_world()
	game.flashlight.set_process(false)
	game.flashlight.input_enabled = false
	game.flashlight.rotation = PI
	hand = game.player.held_flashlight
	scale_value = game.player.dasha_animation.base_scale.x
	var near_aim_stable: bool = true
	var torso: Vector2 = game.player.global_position-Vector2(0,game.flashlight.emission_height())
	var pointer: Vector2 = torso+Vector2(12,-8)
	var wanted_direction: Vector2 = Vector2(12,-8).normalized()
	for view: Array in [["front",false],["front",true],["back",false],["back",true]]:
		pose(view[0],view[1])
		game.flashlight.toggle_flashlight(true,true)
		for angle: float in [-PI,-PI*0.5,0.0,PI*0.5]:
			game.flashlight.rotation = angle
			step()
			near_aim_stable = near_aim_stable and game.flashlight.aim_direction_towards(pointer).distance_to(wanted_direction) < 0.001
			near_aim_stable = near_aim_stable and game.flashlight.body_direction_towards(pointer).distance_to(wanted_direction) < 0.001
	near_aim_stable = near_aim_stable and game.flashlight.aim_direction_towards(torso).is_zero_approx()
	check("near-body cursor does not chase the moving hand or reverse the body",near_aim_stable)
	var initial_position: Vector2 = game.player.position
	game.player.position = Vector2(431.5836,370.6672)
	pose("back",true)
	game.flashlight.rotation = deg_to_rad(2.0)
	game.flashlight.toggle_flashlight(true,true)
	step()
	var wall_elbow: Vector2 = hand.elbow_position
	game.flashlight.rotation = deg_to_rad(3.0)
	step()
	check("wall retraction does not flip the elbow solution",hand.elbow_position.distance_to(wall_elbow) < 1.0*scale_value)
	game.player.position = initial_position

	# Inspect every drawing frame: there must be no translucent extra arm and no
	# lamp before the grip. The lamp's first appearance must happen at the pocket.
	pose("front",false)
	game.flashlight.toggle_flashlight(false,true)
	game.flashlight.toggle_flashlight(true)
	var opaque: bool = true
	var concealed: bool = true
	var first_visible: float = -1.0
	var before_grip: bool = true
	var max_draw_step: float = 0.0
	var previous_wrist: Vector2
	var previous_elbow: Vector2
	for index: int in 60:
		step()
		if hand.visible:
			opaque = opaque and is_equal_approx(hand.modulate.a,1.0)
			for part: Sprite2D in [hand.upper,hand.forearm,hand.palm]:
				if part.visible: opaque = opaque and is_equal_approx(part.modulate.a*part.self_modulate.a,1.0)
		if hand.equip_amount <= 0.29:
			concealed = concealed and not hand.torch.visible
		if first_visible < 0.0 and hand.torch.visible:
			first_visible = hand.equip_amount
		before_grip = before_grip and (hand.equip_amount >= 0.9 or not game.flashlight.is_emitting())
		if index > 0:
			max_draw_step = maxf(max_draw_step,maxf(hand.wrist_position.distance_to(previous_wrist),hand.elbow_position.distance_to(previous_elbow))/scale_value)
		previous_wrist = hand.wrist_position
		previous_elbow = hand.elbow_position
	check("draw uses an opaque arm instead of alpha materialization",opaque)
	check("flashlight stays concealed until the grip phase",concealed)
	check("flashlight first appears while drawing from the pocket",first_visible >= 0.30 and first_visible <= 0.50)
	check("light waits until the arm is raised",before_grip)
	check("draw follows a continuous wrist and elbow path",max_draw_step <= 6.0)
	print("DRAW_MAX_STEP_ATLAS ",max_draw_step," FIRST_TORCH ",first_visible)

	# A sign-based IK branch used to flip the elbow by ~39 atlas pixels when
	# aiming through a vertical direction. Sweep the entire circle in both views.
	for view: Array in [["front",false],["front",true],["back",false],["back",true]]:
		pose(view[0],view[1])
		game.flashlight.rotation = -PI
		game.flashlight.toggle_flashlight(true,true)
		for index: int in 20: step()
		previous_wrist = hand.wrist_position
		previous_elbow = hand.elbow_position
		var maximum: float = 0.0
		var below_shoulder: bool = true
		var finite: bool = true
		var captures: Array[Image] = []
		for index: int in 181:
			game.flashlight.rotation = -PI+TAU*float(index)/180.0
			step()
			maximum = maxf(maximum,maxf(hand.wrist_position.distance_to(previous_wrist),hand.elbow_position.distance_to(previous_elbow))/scale_value)
			below_shoulder = below_shoulder and hand.wrist_position.y >= hand.shoulder_position.y+5.0*scale_value
			finite = finite and hand.wrist_position.is_finite() and hand.elbow_position.is_finite() and hand.lens_position.is_finite()
			previous_wrist = hand.wrist_position
			previous_elbow = hand.elbow_position
			if view[0] == "front" and not view[1] and index%3 == 0:
				var picture: Image = await frame_capture("sweep",index/3)
				if index in [0,24,45,69,90,114,135,159,180]: captures.append(picture)
		var label: String = str(view[0])+" mirrored="+str(view[1])
		check(label+" elbow and wrist remain continuous through vertical aims",maximum <= 4.0)
		check(label+" holds the wrist below the shoulder",below_shoulder)
		check(label+" arm geometry remains finite",finite)
		print("SWEEP_MAX_STEP_ATLAS ",label," ",maximum)
		if not captures.is_empty(): sheet(captures,"sweep-contact",3)

	# Repeat drawing on every breathing frame: a bad skin detector previously
	# mistook a different object for the free hand on idle frame3.
	var breathing_path: bool = true
	for idle_frame: int in 8:
		pose("front",false,idle_frame)
		game.flashlight.rotation = PI
		game.flashlight.toggle_flashlight(false,true)
		game.flashlight.toggle_flashlight(true)
		for index: int in 48:
			step()
			if index > 0:
				breathing_path = breathing_path and hand.wrist_position.distance_to(previous_wrist) <= 6.0*scale_value and hand.elbow_position.distance_to(previous_elbow) <= 6.0*scale_value
			previous_wrist = hand.wrist_position
			previous_elbow = hand.elbow_position
	check("drawing remains continuous on all eight breathing frames",breathing_path)

	# Reversing the command must preserve the current pose at zero elapsed time.
	game.flashlight.toggle_flashlight(false)
	for index: int in 12: step()
	previous_wrist = hand.wrist_position
	previous_elbow = hand.elbow_position
	game.flashlight.toggle_flashlight(true)
	check("rapid toggle preserves the current wrist and elbow",hand.wrist_position.distance_to(previous_wrist) < 0.01 and hand.elbow_position.distance_to(previous_elbow) < 0.01)

	# A full-body sprite reflection is discrete. Its arm must change on that same
	# frame, rather than smoothing the shoulder at an obsolete screen position.
	# Continuity is measured within a view, while attachment is checked even on
	# the actual reflection/front-back transition frames.
	pose("front",false)
	game.flashlight.rotation = PI
	game.flashlight.toggle_flashlight(false,true)
	game.flashlight.toggle_flashlight(true)
	var turn_maximum: float = 0.0
	var shoulder_error: float = 0.0
	var turn_attached: bool = true
	var turn_finite: bool = true
	var previous_facing: String = "front"
	var previous_mirrored: bool = false
	var turn_captures: Array[Image] = []
	for index: int in 60:
		if index == 18: pose("front",true)
		if index == 32: pose("back",true)
		if index == 44: pose("back",false)
		game.flashlight.rotation = lerpf(PI,0.0,float(index)/59.0)
		step()
		var sprite: Sprite2D = game.player.sprite
		var animator: DashaAnimation = game.player.dasha_animation
		var table: String = "idle" if sprite.texture == DashaAnimation.IDLE_ATLAS else "main"
		var socket: Dictionary = HeldFlashlight.SOCKETS.POSES[table][sprite.frame]
		var point: Vector2 = Vector2(socket.shoulder[0],socket.shoulder[1])
		if sprite.flip_h: point.x = 160.0-point.x
		var expected_shoulder: Vector2 = (point+sprite.offset)*sprite.scale+sprite.position
		shoulder_error = maxf(shoulder_error,hand.shoulder_position.distance_to(expected_shoulder)/scale_value)
		turn_attached = turn_attached and hand.shoulder_position.distance_to(expected_shoulder) < 0.01 and hand.upper.position.distance_to(expected_shoulder) < 0.01
		turn_attached = turn_attached and hand.forearm.position.distance_to(hand.elbow_position) < 0.01 and hand.palm.position.distance_to(hand.wrist_position) < 0.01 and hand.torch.position.distance_to(hand.wrist_position) < 0.01
		turn_finite = turn_finite and hand.shoulder_position.is_finite() and hand.elbow_position.is_finite() and hand.wrist_position.is_finite() and hand.lens_position.is_finite()
		if index > 0 and previous_facing == animator.facing and previous_mirrored == sprite.flip_h:
			turn_maximum = maxf(turn_maximum,maxf(hand.wrist_position.distance_to(previous_wrist),hand.elbow_position.distance_to(previous_elbow))/scale_value)
		previous_facing = animator.facing
		previous_mirrored = sprite.flip_h
		previous_wrist = hand.wrist_position
		previous_elbow = hand.elbow_position
		if index%2 == 0:
			var picture: Image = await frame_capture("turn-draw",index/2)
			if index in [0,16,18,20,30,32,34,42,44,46,50,58]: turn_captures.append(picture)
	check("turning registers the shoulder on the current body frame without limb lag",turn_attached and turn_finite and turn_maximum <= 6.0)
	print("TURN_DRAW_SAME_VIEW_MAX_STEP_ATLAS ",turn_maximum," SHOULDER_ERROR_ATLAS ",shoulder_error)
	sheet(turn_captures,"turn-draw-contact",4)

	# This preview is captured from the actual room renderer, at30 simulation fps.
	pose("front",false)
	game.flashlight.rotation = PI
	game.flashlight.toggle_flashlight(false,true)
	var draw_captures: Array[Image] = []
	for index: int in 84:
		if index == 0: game.flashlight.toggle_flashlight(true)
		if index == 42: game.flashlight.toggle_flashlight(false)
		step(1.0/30.0)
		var picture: Image = await frame_capture("draw-stow",index)
		if index in [0,5,10,15,20,25,35,42,47,52,57,65]: draw_captures.append(picture)
	sheet(draw_captures,"draw-stow-contact",6)
	print("ARM_MOTION_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
