extends SceneTree

var failures: int = 0
var output_directory: String = ""

func _initialize() -> void:
	call_deferred("run")

func check(title: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + title)
	if not passed: failures += 1

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-"):
		quit(1)
		return
	output_directory = OS.get_environment("KAMDRAAA_ANIMATION_CAPTURE_DIR")
	if output_directory.is_empty(): output_directory = ProjectSettings.globalize_path("res://AI/review/images/animation/")
	var stage: Node2D = Node2D.new()
	root.add_child(stage)
	var actor: CharacterBody2D = CharacterBody2D.new()
	actor.set_script(load("res://scripts/player.gd"))
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "DashaSprite"
	sprite.texture = load("res://assets/sprites/dasha.png")
	sprite.scale = Vector2(0.28, 0.28)
	actor.add_child(sprite)
	stage.add_child(actor)
	actor.set_physics_process(false)
	var anim: DashaAnimation = actor.dasha_animation
	check("idle uses its dedicated registered atlas", sprite.hframes == 8 and sprite.vframes == 4 and sprite.texture == DashaAnimation.DETAILED_IDLE_ATLAS and sprite.material == anim.body_material)
	check("feet anchored to frame baseline", not sprite.centered and sprite.offset == Vector2(-80, -244))
	anim.update(0.1, Vector2(180, 70), "walk", 30, false)
	check("walk selects detailed front pose and flips right", anim.animation_state == "walk" and anim.facing == "front" and sprite.flip_h and sprite.texture == DashaAnimation.DETAILED_ATLAS)
	var first: int = sprite.frame
	anim.update(0.1, Vector2(180, 70), "walk", 60, false)
	check("walk frames advance with distance", sprite.frame != first)
	first = sprite.frame
	anim.update(0.1, Vector2(180, 70), "walk", 60, false)
	check("walking into obstruction does not cycle feet", sprite.frame == first)
	anim.update(0.1,Vector2(-145,-145),"walk",70,false,Vector2(-1,-1).normalized())
	check("up-left selects back left",anim.facing == "back" and not sprite.flip_h)
	anim.update(0.016,Vector2(-185,-100),"walk",73,false,Vector2.LEFT)
	check("releasing W while holding A immediately faces front left",anim.facing == "front" and not sprite.flip_h)
	anim.update(0.1,Vector2(145,-145),"walk",80,false,Vector2(1,-1).normalized())
	check("up-right selects back right",anim.facing == "back" and sprite.flip_h)
	anim.update(0.016,Vector2(185,-100),"walk",83,false,Vector2.RIGHT)
	check("releasing W while holding D immediately faces front right",anim.facing == "front" and sprite.flip_h)
	anim.update(0.1, Vector2(-220, -100), "run", 100, false)
	check("run has its own detailed back poses", anim.animation_state == "run" and anim.facing == "back" and not sprite.flip_h and sprite.frame >= 40 and sprite.frame < 48 and sprite.texture == DashaAnimation.DETAILED_ATLAS)
	anim.update(0.1, Vector2.ZERO, "sneak", 100, false)
	check("stationary crouch starts a real transition", anim.animation_state == "crouch_enter" and anim.frame_index > 0 and anim.frame_index < 7)
	anim.update(0.3, Vector2.ZERO, "sneak", 100, false)
	check("holding crouch remains crouched while stationary", anim.animation_state == "crouch_idle" and anim.crouch_amount == 1 and sprite.texture == DashaAnimation.DETAILED_IDLE_ATLAS)
	var rest_frame: int = sprite.frame
	var rest_scale: Vector2 = sprite.scale
	anim.update(0.8,Vector2.ZERO,"sneak",100,false)
	check("crouched rest breathes without enlarging its registered pose",not sprite.scale.is_equal_approx(rest_scale) and sprite.scale.y <= anim.base_scale.y and anim.animation_state == "crouch_idle")
	anim.update(0.1, Vector2(-80,-40), "sneak", 130, false)
	check("crouched locomotion uses independent cycle", anim.animation_state == "crouch_walk" and sprite.frame >= 48 and sprite.frame < 56)
	anim.update(0.1, Vector2.ZERO, "walk", 130, false)
	check("releasing crouch plays stand-up transition", anim.animation_state == "crouch_exit" and anim.frame_index > 0 and anim.frame_index < 7)
	anim.update(0.3, Vector2.ZERO, "walk", 130, false)
	check("stand-up finishes in idle", anim.animation_state == "idle" and anim.crouch_amount == 0)
	anim.show_pose("idle",0,"front")
	rest_frame = sprite.frame
	var idle_image: Image = sprite.texture.get_image()
	var resting_bitmap: Image = idle_image.get_region(Rect2i(rest_frame * 160,0,160,256))
	rest_scale = sprite.scale
	anim.update(0.67,Vector2.ZERO,"walk",130,false)
	var current_bitmap: Image = idle_image.get_region(Rect2i(sprite.frame * 160,0,160,256))
	check("front rest breathes continuously with registered silhouette",current_bitmap.get_used_rect() == resting_bitmap.get_used_rect() and not sprite.scale.is_equal_approx(rest_scale) and sprite.scale.y <= anim.base_scale.y and anim.animation_state == "idle")
	anim.show_pose("idle",0,"front")
	check("idle uses detailed character art", sprite.texture == DashaAnimation.DETAILED_IDLE_ATLAS)
	anim.show_pose("run",0,"front")
	check("run uses detailed character art", sprite.texture == DashaAnimation.DETAILED_ATLAS)
	anim.update(0.4, Vector2(200,0), "run", 140, true)
	check("locked actor does not play locomotion", anim.animation_state == "idle")
	check("footsteps follow half-stride for all gaits", anim.step_distance("walk") == 82 and anim.step_distance("run") == 110 and anim.step_distance("sneak") == 50)
	anim.update(0.1, Vector2.ZERO, "sneak", 140, false)
	var bent: float = anim.crouch_amount
	anim.update(0.04, Vector2.ZERO, "walk", 140, false)
	check("stationary crouch can reverse smoothly", anim.animation_state == "crouch_exit" and anim.crouch_amount < bent and anim.crouch_amount > 0)
	anim.update(0.4, Vector2.ZERO, "walk", 140, false)
	anim.update(0.1, Vector2(200,0), "walk", 180, false)
	var phase: float = anim.cycle_phase
	anim.update(0.0, Vector2(300,0), "run", 180, false)
	check("walk to run keeps gait phase", is_equal_approx(anim.cycle_phase, phase) and anim.animation_state == "run")
	anim.update(0.0, Vector2(200,0), "walk", 180, false)
	check("run to walk keeps gait phase", is_equal_approx(anim.cycle_phase, phase) and anim.animation_state == "walk")
	actor.movement_mode = "run"
	actor.set_control_locked(true)
	check("modal lock immediately settles running sprite", anim.animation_state == "idle" and not actor.is_physics_processing())
	actor.set_control_locked(false)
	actor.movement_mode = "sneak"
	anim.update(0.15, Vector2.ZERO, "sneak", 180, false)
	var interrupted_frame: int = sprite.frame
	var interrupted_amount: float = anim.crouch_amount
	actor.set_control_locked(true)
	check("modal lock preserves an interrupted posture without a size jump", sprite.frame == interrupted_frame and is_equal_approx(anim.crouch_amount,interrupted_amount))
	actor.set_control_locked(false)
	actor.movement_mode = "run"
	actor.speed = 325
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	actor.add_child(shape)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = Vector2(55,0)
	var wall_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(20,200)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	stage.add_child(wall)
	await physics_frame
	Input.action_press("move_right")
	for step: int in 30:
		await physics_frame
		actor._physics_process(1.0/60.0)
	Input.action_release("move_right")
	check("actual wall collision settles run in idle", actor.position.x < 34 and actor.velocity.length() < 1 and anim.animation_state == "idle")
	actor.position = Vector2(-300,0)
	actor.velocity = Vector2.ZERO
	actor.movement_mode = "walk"
	actor.speed = 205
	for horizontal: String in ["move_left","move_right"]:
		Input.action_press("move_up")
		Input.action_press(horizontal)
		for step: int in 10:
			await physics_frame
			actor._physics_process(1.0/60.0)
		check("diagonal input looks back " + horizontal,anim.facing == "back")
		Input.action_release("move_up")
		await physics_frame
		actor._physics_process(1.0/60.0)
		check("real W release fixes facing " + horizontal,anim.facing == "front" and sprite.flip_h == (horizontal == "move_right"))
		Input.action_release(horizontal)
		actor.velocity = Vector2.ZERO
	var image: Image = DashaAnimation.ATLAS.get_image()
	var standing: Rect2i = image.get_region(Rect2i(0,3*256,160,256)).get_used_rect()
	var crouching: Rect2i = image.get_region(Rect2i(7*160,3*256,160,256)).get_used_rect()
	check("crouch genuinely lowers silhouette", crouching.size.y < standing.size.y * 0.7)
	var grounded: bool = true
	for row: int in 8:
		for frame: int in 8:
			var pose: Rect2i = image.get_region(Rect2i(frame*160,row*256,160,256)).get_used_rect()
			var expected: int = 237 if row in [1,5] and frame in [2,6] else 244
			if pose.end.y != expected: grounded = false
	check("all 64 poses registered; run flight explicitly raised", grounded)
	# Exercise every source state into every stable destination, in both views.
	# Inspect the actual selected bitmap as well as the state-machine fields.
	var textures: Dictionary = {DashaAnimation.ATLAS: DashaAnimation.ATLAS.get_image(), DashaAnimation.IDLE_ATLAS: DashaAnimation.IDLE_ATLAS.get_image(), DashaAnimation.DETAILED_ATLAS: DashaAnimation.DETAILED_ATLAS.get_image(), DashaAnimation.DETAILED_IDLE_ATLAS: DashaAnimation.DETAILED_IDLE_ATLAS.get_image()}
	var transitions_valid: bool = true
	var anatomy_valid: bool = true
	var pair_count: int = 0
	for direction: String in ["front","back"]:
		for source: String in ["idle","walk","run","crouch_enter","crouch_exit","crouch_idle","crouch_walk"]:
			for destination: String in ["idle","walk","run","crouch_idle","crouch_walk"]:
				pair_count += 1
				anim.crouch_amount = 0.5 if source in ["crouch_enter","crouch_exit"] else 1.0 if source.begins_with("crouch") else 0.0
				anim.show_pose(source,4,direction)
				anim.last_walk_distance = 0.0
				var distance: float = 0.0
				for frame: int in 32:
					var mode: String = "sneak" if destination.begins_with("crouch") else "run" if destination == "run" else "walk"
					var travel: Vector2 = Vector2.ZERO if destination in ["idle","crouch_idle"] else Vector2(-100,-60 if direction == "back" else 60)
					distance += travel.length()/60.0
					anim.update(1.0/60.0,travel,mode,distance,false)
					transitions_valid = transitions_valid and anim.crouch_amount >= 0 and anim.crouch_amount <= 1 and sprite.scale.x == anim.base_scale.x and sprite.scale.y <= anim.base_scale.y and sprite.scale.y >= anim.base_scale.y*0.993 and sprite.position == Vector2.ZERO
					var cell: Image = (textures[sprite.texture] as Image).get_region(Rect2i(sprite.frame_coords*Vector2i(160,256),Vector2i(160,256)))
					var used: Rect2i = cell.get_used_rect()
					var width: int = 0
					for x: int in 160:
						if cell.get_pixel(x,used.position.y+15).a > 0.5: width += 1
					# At 200px standing height the original character has a 36px
					# front head contour; its registered rear reference is 38px.
					var skull: float = 36.0 if direction == "front" else 38.0
					anatomy_valid = anatomy_valid and float(width)/skull < 1.15 and float(width)/skull > 0.85 and used.size.y <= 201
				transitions_valid = transitions_valid and anim.animation_state == destination
	check("all 70 state pairs finish without resizing or foot-pivot jumps", transitions_valid and pair_count == 70)
	check("every transition keeps comparable skull scale and never enlarges crouch", anatomy_valid)
	var identical_endpoints: bool = true
	for view: int in 2:
		var end_pose: Image = DashaAnimation.DETAILED_ATLAS.get_image().get_region(Rect2i(7*160,(3+view*4)*256,160,256))
		var resting: Image = DashaAnimation.DETAILED_IDLE_ATLAS.get_image().get_region(Rect2i(0,(2+view)*256,160,256))
		identical_endpoints = identical_endpoints and end_pose.get_data() == resting.get_data()
	check("crouch transition and resting pose are the same registered drawing", identical_endpoints)
	check("character uses nearest filtering", sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	anim.show_pose("walk",0,"front")
	check("movement clarity retains the same material and pixel filtering", sprite.material == anim.body_material and anim.clarity_amount > 0.0 and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	if DisplayServer.get_name() != "headless":
		RenderingServer.set_default_clear_color(Color("1b201e"))
		actor.visible = false
		for index: int in 8:
			var preview: Sprite2D = Sprite2D.new()
			preview.texture = load("res://assets/sprites/dasha.png")
			preview.scale = Vector2(0.28,0.28)
			stage.add_child(preview)
			var poses: DashaAnimation = DashaAnimation.new()
			poses.setup(preview)
			poses.show_pose(["idle","walk","run","crouch_enter","crouch_idle","crouch_walk","run","crouch_walk"][index], [0,2,2,4,7,3,4,6][index], "back" if index >= 6 else "front")
			preview.position = Vector2(90 + index*155, 370)
			var title: Label = Label.new()
			title.text = ["Покой","Ходьба","Бег","Приседание","В приседе","Красться","Бег / спина","Красться / спина"][index]
			title.position = Vector2(20 + index*155,410)
			title.add_theme_font_size_override("font_size", 14)
			stage.add_child(title)
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output_directory)
		check("animation preview saved", root.get_texture().get_image().save_png(output_directory.path_join("states.png")) == OK)
	print("ANIMATION_CHECK failures=", failures)
	quit(0 if failures == 0 else 1)
