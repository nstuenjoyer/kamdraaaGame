extends SceneTree
var failures: int = 0
var checks: int = 0
var game: Node2D
var output_directory: String
func _initialize() -> void: call_deferred("run")
func check(label: String, result: bool) -> void:
	checks += 1
	print(("PASS " if result else "FAIL ")+label)
	if not result: failures += 1
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	check(name_value+" capture",root.get_texture().get_image().save_png(output_directory+name_value+".png") == OK)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/chapter-check-"):
		quit(1)
		return
	var review_root: String = OS.get_environment("KAMDRAAA_HELD_REVIEW_ROOT").replace("\\","/")
	if review_root.is_empty():
		quit(1)
		return
	output_directory = review_root.path_join("AI/review/images/held-flashlight/")
	DirAccess.make_dir_recursive_absolute(output_directory)
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
	game.player.position = ApartmentWorld.iso(Vector2(380,390))
	game.player.get_node("Camera2D").zoom = Vector2(2.3,2.3)
	game.player.get_node("Camera2D").reset_smoothing()
	game.flashlight.input_enabled = false
	game.flashlight.rotation = PI
	game.flashlight.available = true
	game.state.mark("power")
	game.state.mark("flashlight")
	game._refresh_world()
	var hand: HeldFlashlight = game.player.held_flashlight
	check("starts stowed",not hand.visible and not game.flashlight.is_emitting())
	game.flashlight.toggle_flashlight(true)
	check("draw does not light feet immediately",not game.flashlight.cone_light.enabled)
	await create_timer(0.12).timeout
	check("draw animation in progress",hand.equip_amount > 0 and hand.equip_amount < 1)
	await shot("01-drawing")
	await create_timer(0.70).timeout
	check("draw finishes with held light",hand.equip_amount == 1 and game.flashlight.is_emitting() and game.flashlight.cone_light.enabled)
	check("lens raised above feet",game.flashlight.emission_position().y < game.player.global_position.y-25)
	check("beam texture starts at lens",(game.flashlight.cone_light.global_position+game.flashlight.cone_light.offset.rotated(game.flashlight.global_rotation)).distance_to(game.flashlight.emission_position()) < 0.1)
	game.flashlight.set_process(false)
	for entry: Array in [["02-front-left","idle","front",false,PI,0.0],["03-front-right","idle","front",true,0.0,0.0],["04-back-left","idle","back",false,-PI*0.75,0.0],["05-back-right","idle","back",true,-PI*0.25,0.0],["06-crouch","crouch_idle","front",false,PI,1.0],["07-crouch-walk","crouch_walk","front",false,PI,1.0],["08-walk","walk","front",false,PI,0.0],["09-run","run","front",true,0.0,0.0]]:
		game.player.dasha_animation.crouch_amount = entry[5]
		game.player.dasha_animation.show_pose(entry[1],2,entry[2])
		game.player.sprite.flip_h = entry[3]
		game.flashlight.rotation = entry[4]
		game.flashlight.toggle_flashlight(true,true)
		game.flashlight._process(0.0)
		game.world.update_lighting(game.player.position,Vector2.RIGHT.rotated(game.flashlight.rotation),game.flashlight.is_emitting(),true,game.flashlight.emission_position(),game.flashlight.emission_height())
		check(str(entry[0])+" hand and beam stay linked",(game.player.global_position+hand.lens_position).distance_to(game.flashlight.emission_position()) < 0.1)
		await shot(entry[0])
	game.flashlight.toggle_flashlight(false)
	check("off extinguishes beam before stowing",not game.flashlight.cone_light.enabled and not game.flashlight.is_emitting())
	game.flashlight._process(0.12)
	check("stow has intermediate pose",hand.equip_amount > 0 and hand.equip_amount < 1)
	game.flashlight._process(0.6)
	check("stow removes held model and arm override",not hand.visible and game.player.sprite.material == null)
	game.flashlight.toggle_flashlight(true,true)
	check("restore snaps into held pose",hand.equip_amount == 1 and game.flashlight.is_emitting())
	game.flashlight.toggle_flashlight(false)
	game.flashlight._process(0.12)
	var partial: float = hand.equip_amount
	game.flashlight.toggle_flashlight(true)
	game.flashlight._process(0.05)
	check("repeated toggle reverses presentation continuously",hand.equip_amount > partial and hand.equip_amount < 1)
	game.player.set_control_locked(true)
	partial = hand.equip_amount
	var locked_angle: float = game.flashlight.rotation
	game.flashlight.input_enabled = true # The controller's previous-frame flag may still allow input.
	var toggle_event: InputEventAction = InputEventAction.new()
	toggle_event.action = "toggle_flashlight"
	toggle_event.pressed = true
	game.flashlight._input(toggle_event)
	game.flashlight._process(0.6)
	check("dialogue locks drawing, aim and stale toggle input",is_equal_approx(partial,hand.equip_amount) and is_equal_approx(locked_angle,game.flashlight.rotation) and game.flashlight.is_on())
	game.flashlight.input_enabled = false
	game.player.set_control_locked(false)
	game.flashlight._process(0.3)
	check("drawing resumes after dialogue",hand.equip_amount == 1.0 and game.flashlight.is_emitting())
	game.flashlight.toggle_flashlight(true,true)
	var linked: bool = true
	var poses: int = 0
	for row: int in 8:
		for frame: int in 8:
			var state: String = ["walk","run","crouch_walk","crouch_enter"][row%4]
			game.player.dasha_animation.crouch_amount = 1.0 if row%4 == 2 else float(frame)/7.0 if row%4 == 3 else 0.0
			game.player.dasha_animation.show_pose(state,frame,"back" if row>=4 else "front")
			for mirrored: bool in [false,true]:
				game.player.sprite.flip_h = mirrored
				game.flashlight.rotation = 0.0 if mirrored else PI
				game.flashlight._process(0.0)
				linked = linked and hand.lens_position.is_finite() and hand.wrist_position.is_finite() and absf(game.flashlight.position.y-hand.lens_position.y-hand.emission_height)<0.01
				poses += 1
	check("held arm tracks all 128 locomotion poses and mirrored views",linked and poses == 128)
	game.flashlight.available = false
	game.flashlight._process(0.7)
	game.flashlight.toggle_flashlight(true)
	check("unavailable flashlight cannot emit or remain in hand",not game.flashlight.is_emitting() and not hand.visible)
	game.flashlight.available = true
	# Capture actual rendered draw/stow frames, not an asset-only mockup.
	game.player.dasha_animation.crouch_amount = 0
	game.player.dasha_animation.show_pose("idle",0,"front")
	game.player.sprite.flip_h = false
	game.flashlight.rotation = PI
	game.flashlight.toggle_flashlight(false,true)
	var frame_directory: String = review_root.path_join(".godot/held-flashlight-frames/")
	DirAccess.make_dir_recursive_absolute(frame_directory)
	var captured: bool = true
	for frame: int in 48:
		if frame == 0: game.flashlight.toggle_flashlight(true)
		if frame == 28: game.flashlight.toggle_flashlight(false)
		game.flashlight._process(1.0/30.0)
		game.world.update_lighting(game.player.position,Vector2.LEFT,game.flashlight.is_emitting(),true,game.flashlight.emission_position(),game.flashlight.emission_height())
		await process_frame
		await RenderingServer.frame_post_draw
		var center: Vector2i = Vector2i(game.world.get_global_transform_with_canvas()*game.player.global_position)
		var crop: Rect2i = Rect2i(center-Vector2i(180,320),Vector2i(360,370)).intersection(Rect2i(Vector2i.ZERO,root.get_texture().get_image().get_size()))
		captured = root.get_texture().get_image().get_region(crop).save_png(frame_directory+"%02d.png"%frame) == OK and captured
	check("draw and stow animation frames captured",captured)
	# Exercise the real process order at the draw threshold, not a manual light update.
	game.state.mark("intro")
	game.flashlight.toggle_flashlight(false,true)
	game.flashlight.set_process(true)
	game.set_process(true)
	game.flashlight.toggle_flashlight(true)
	var coherent: bool = true
	var observed_light: bool = false
	var deadline: int = Time.get_ticks_msec()+1100
	while Time.get_ticks_msec() < deadline:
		await process_frame
		await RenderingServer.frame_post_draw
		var material: ShaderMaterial = game.world.wall_materials[0]
		coherent = coherent and bool(material.get_shader_parameter("torch_on")) == game.flashlight.is_emitting()
		coherent = coherent and Vector2(material.get_shader_parameter("torch_emission_position")).distance_to(game.flashlight.emission_position()) < 0.1
		observed_light = observed_light or game.flashlight.is_emitting()
	check("wall light and held lamp use the same rendered frame",coherent and observed_light)
	print("HELD_FLASHLIGHT_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
