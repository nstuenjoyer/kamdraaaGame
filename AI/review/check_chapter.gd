extends SceneTree

var game: Node2D
var failures: int = 0
var checks: int = 0
var initial: Dictionary
var first_dose: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(title: String, value: bool) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + title)
	if not value: failures += 1

func interact(id: String) -> void:
	game.ui.close()
	# Explicit post-investigation fixtures for the existing combat/inventory regressions.
	# The causal route is tested separately in check_apartment_route.gd.
	if id == "front_key":
		for flag: String in ["exit_checked", "jacket_checked", "study_key", "study_unlocked", "cabinet_checked", "cabinet_unlocked", "latch_released"]: game.state.mark(flag)
	if id == "diary": game.state.mark("sofa_searched")
	if id == "fusebox": game.story.breakers.assign([true, true, false])
	game.interact(id)

func walk_to(logical: Vector2) -> bool:
	var target: Vector2 = ApartmentWorld.iso(logical)
	var path: PackedVector2Array = game.world.route(game.player.position, target)
	var iterations: int = 0
	while not path.is_empty() and iterations < 2200:
		iterations += 1
		while not path.is_empty() and game.player.position.distance_to(path[0]) < 22.0: path.remove_at(0)
		if path.is_empty(): break
		var direction: Vector2 = game.player.position.direction_to(path[0])
		Input.action_press("move_right", maxf(0, direction.x))
		Input.action_press("move_left", maxf(0, -direction.x))
		Input.action_press("move_down", maxf(0, direction.y))
		Input.action_press("move_up", maxf(0, -direction.y))
		await physics_frame
	for action: String in ["move_right", "move_left", "move_down", "move_up"]: Input.action_release(action)
	game.player.velocity = Vector2.ZERO
	return game.player.position.distance_to(target) < 65.0

func enemy_reaches(logical: Vector2) -> bool:
	var target: Vector2 = ApartmentWorld.iso(logical)
	game.enemy.hear(target)
	game.enemy.grace = 100.0
	for i: int in 1000:
		await physics_frame
		if game.enemy.position.distance_to(target) < 48.0: return true
	return false

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().contains("/.godot/chapter-check-"):
		push_error("Use tools/run_chapter_checks.ps1 to isolate saves/settings from player data")
		quit(1)
		return
	change_scene_to_file("res://scenes/chapter_1/apartment.tscn")
	await process_frame
	await process_frame
	await create_timer(1.65).timeout
	game = current_scene
	while game.intro_active: await process_frame
	check("intro explains stress", game.ui.modal_kind == "message" and game.state.has("intro"))
	check("opening does not immediately assign pills", not game.state.has("opening_done") and not game.ui.hud.visible)
	while root.get_node("ParanoiaManager").get_paranoia() < 99.0: game.ui.advance_message()
	check("initial hallucination at maximum stress", is_equal_approx(root.get_node("ParanoiaManager").get_paranoia(), 100.0))
	check("flashlight unavailable before pickup", not game.flashlight.available and not game.flashlight.is_on())
	game.flashlight.toggle_flashlight(true)
	check("hotkey cannot grant flashlight", not game.flashlight.is_on())
	game.ui.close()
	initial = game.export_chapter_save().duplicate(true)
	check("bedroom doorway traversable before pill", await walk_to(Vector2(800, 450)))
	game.interact("key_rack")
	check("exploration allowed before pill", game.state.has("study_key") and not game.state.has("dose"))
	game.import_chapter_save(initial.duplicate(true))
	game.ui.close()
	interact("pills")
	check("blister not discoverable before bed", not game.state.has("pills"))
	interact("bed")
	check("bed reveals blister", game.world.interactables.pills.visible)
	interact("pills")
	check("exactly two initial pills", root.get_node("InventoryManager").get_item_count("pills") == 2)
	interact("pills")
	check("cannot duplicate blister", root.get_node("InventoryManager").get_item_count("pills") == 2)
	game.ui.inventory()
	root.get_node("InventoryManager").use_item("pills")
	game.ui.close()
	await process_frame
	check("mandatory dose releases gate", game.state.has("dose") and not is_instance_valid(game.tutorial_gate))
	check("one dose remains", root.get_node("InventoryManager").get_item_count("pills") == 1)
	check("pill reduces stress by 40", is_equal_approx(root.get_node("ParanoiaManager").get_paranoia(), 60.0))
	game.set_process(false)
	root.get_node("ParanoiaManager")._process(120.0)
	game.set_process(true)
	check("no passive stress decay", is_equal_approx(root.get_node("ParanoiaManager").target_paranoia, 60.0))
	var legacy_path: String = "user://saves/slot_3.json"
	var legacy_file: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string("{\"version\":2,\"quest\":{}}")
	legacy_file.close()
	var legacy_bytes: String = FileAccess.get_file_as_string(legacy_path)
	check("historical slot labelled incompatible", not root.get_node("SaveManager").get_save_info("slot_3").get("compatible", true))
	check("historical slot cannot load into chapter", not root.get_node("SaveManager").load_game("slot_3"))
	first_dose = game.export_chapter_save().duplicate(true)
	interact("front_key")
	interact("exit")
	check("door explains missing diary decision", game.state.phase == "exploration" and game.ui.modal_kind.is_empty())
	interact("cupboard_key")
	check("key hidden under vase", not game.state.has("cupboard_key"))
	interact("fusebox")
	check("power requires both tools", not game.state.has("power"))
	game.ui.close()
	for choice: String in ["trust", "dismiss"]:
		for power: bool in [false, true]:
			game.import_chapter_save(first_dose.duplicate(true))
			game.ui.close()
			interact("front_key")
			if power:
				interact("fuse")
				interact("screwdriver")
				interact("fusebox")
				game.ui.content.get_child(game.ui.content.get_child_count() - 2).pressed.emit()
				check("repair powers apartment", game.state.has("power"))
				check("fuse consumed once", not root.get_node("InventoryManager").has_item("fuse"))
			interact("diary")
			game.ui.close()
			game.choose_diary(choice)
			var belief: float = game.state.belief
			game.choose_diary(choice)
			check("diary decision idempotent " + choice, game.state.belief == belief)
			interact("exit")
			check("coat triggered in both branches", game.ui.modal_kind == "qte")
			for i: int in 10: game.ui.qte_press("move_left" if i % 2 == 0 else "move_right")
			game.ui._process(0.01)
			check("QTE reveals coat", game.state.has("coat") and game.ui.modal_kind == "message")
			game.ui.close()
			game.checkpoint()
			game.begin_encounter()
			check("real encounter exists without optional gear", is_instance_valid(game.enemy))
			game.ui.close()
			var retry: Dictionary = game.state.checkpoint.duplicate(true)
			game.enemy.stun(8.0)
			check("escape without pepper/flashlight", game.can_escape())
			game.finish_scene("stealth")
			check("stealth outcome saved", game.state.outcome == "stealth" and game.state.events.size() == 1)
			game.retry_checkpoint()
			check("retry rolls back outcomes and inventory", game.state.outcome.is_empty() and game.state.events.is_empty() and game.state.phase == "coat_done")
			check("checkpoint is not recursive", retry.get("checkpoint", {}).is_empty())
	game.import_chapter_save(first_dose.duplicate(true))
	game.ui.close()
	for id: String in ["front_key", "vase", "cupboard_key", "cupboard", "rope", "heavy", "flashlight", "phone", "screwdriver", "fuse"]:
		interact(id)
	check("cupboard key consumed; pepper granted", not root.get_node("InventoryManager").has_item("cupboard_key") and root.get_node("InventoryManager").get_item_count("pepper") == 1)
	game.choose_diary("trust")
	game.finish_coat()
	game.ui.close()
	game.checkpoint()
	game.begin_encounter()
	game.ui.close()
	game.player.position = game.enemy.position + Vector2(80, 0)
	game.flashlight.rotation = PI
	check("pepper works at close range", game.use_pepper())
	check("one pepper charge", not root.get_node("InventoryManager").has_item("pepper") and not game.use_pepper())
	check("nonlethal outcome", game.resolve_enemy("restrained") and game.state.outcome == "restrained")
	game.ui.close()
	check("nonlethal event once", game.state.events.size() == 1 and not game.state.record_outcome("lethal"))
	game.state.checkpoint = first_dose.duplicate(true)
	game.retry_checkpoint()
	check("retry restores original pill count", root.get_node("InventoryManager").get_item_count("pills") == 1)
	interact("front_key")
	interact("heavy")
	game.choose_diary("dismiss")
	game.state.mark("coat")
	game.state.phase = "coat_done"
	game.begin_encounter()
	game.ui.close()
	game.enemy.stun(8.0)
	check("lethal outcome available and distinct", game.resolve_enemy("lethal") and game.state.events["chapter_1.encounter"].chaos == 2)
	game.ui.close()
	game.checkpoint()
	check("v3 serializes", root.get_node("SaveManager").save_game("chapter_test"))
	var saved: Dictionary = game.export_chapter_save()
	check("valid schema", ApartmentState.valid(saved))
	check("valid schema after JSON roundtrip", ApartmentState.valid(JSON.parse_string(JSON.stringify(saved))))
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.chapter.flags = "broken"
	check("reject corrupted flags", not ApartmentState.valid(corrupt))
	game.ui.message("test", "test")
	check("cannot save during modal", not root.get_node("SaveManager").save_game("chapter_mid_action"))
	game.ui.close()
	check("load v3 in current scene", root.get_node("SaveManager").load_game("chapter_test"))
	check("load preserves outcome", game.state.outcome == "lethal")
	# Full navigation connectivity, including every usable target from an actual walkable approach point.
	var reachable: bool = true
	var start: int = game.world.graph.get_closest_point(ApartmentWorld.iso(Vector2(370, 320)))
	for point: Vector2 in game.world.nav_points:
		if game.world.graph.get_id_path(start, game.world.graph.get_closest_point(point)).is_empty():
			reachable = false
			print("UNREACHABLE ", ApartmentWorld.grid(point))
	check("all navigation cells connected", reachable)
	for id: String in game.world.interactables:
		var target: Vector2 = game.world.interactables[id].position
		var near: Vector2 = game.world.graph.get_point_position(game.world.graph.get_closest_point(target))
		check("reachable target " + id, near.distance_to(target) < 94.0 and game.world.clear_line(near, target, false) and not game.world.graph.get_id_path(start, game.world.graph.get_closest_point(near)).is_empty())
	game.import_chapter_save(first_dose.duplicate(true))
	game.ui.close()
	for id: String in ["phone", "screwdriver", "fuse"]: interact(id)
	game.ui.close()
	interact("charger")
	check("charger requires power", not game.state.has("phone_charging"))
	interact("fusebox")
	game.ui.content.get_child(game.ui.content.get_child_count() - 2).pressed.emit()
	interact("charger")
	game._process(21.0)
	check("phone charges in gameplay time", game.state.has("phone_ready"))
	game.read_document("messages")
	check("phone messages in journal", game.state.documents.has("messages"))
	game.ui.close()
	game.read_document("messages")
	check("document collection idempotent", game.state.documents.count("messages") == 1)
	game.ui.close()
	# QTE time and assist are independent of frame count. Wrong presses and pause cannot silently complete it.
	for fps: int in [30, 60, 144]:
		game.state.flags["coat"] = false
		game.ui.begin_qte()
		game.ui.qte_press("move_right")
		check("QTE wrong press " + str(fps), is_zero_approx(game.ui.qte_progress))
		game.ui.qte_paused = true
		game.ui._process(30.0)
		check("QTE pause " + str(fps), is_zero_approx(game.ui.qte_time))
		game.ui.qte_paused = false
		game.ui.qte_assist = true
		for i: int in fps * 4 + 1:
			if game.ui.modal_kind == "qte": game.ui._process(1.0 / fps)
		check("QTE assist at " + str(fps) + " FPS", game.state.has("coat"))
		game.ui.close()
	game.ui.begin_qte()
	game.ui._process(18.1)
	check("QTE timeout offers retry", game.ui.modal_kind == "qte_retry")
	game.ui.begin_qte()
	root.get_node("SettingsManager").rebind_action("move_left", KEY_Z)
	var remapped: InputEventKey = InputEventKey.new()
	remapped.physical_keycode = KEY_Z
	remapped.pressed = true
	game.ui._input(remapped)
	check("QTE accepts remapped action", game.ui.qte_progress == 1.0)
	root.get_node("SettingsManager").reset_keybinds_to_defaults()
	game.ui.close()
	game.state.phase = "exploration"
	game.player.set_control_locked(false)
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 6.0
	for point: Vector2 in [Vector2(800, 450), Vector2(1200, 320), Vector2(1200, 720), Vector2(1350, 1400), Vector2(800, 1600), Vector2(400, 1300), Vector2(370, 320)]:
		check("physical player route " + str(point), await walk_to(point))
	game.state.mark("front_key")
	game.state.mark("coat")
	game.state.phase = "coat_done"
	game.choose_diary("dismiss")
	game.begin_encounter()
	game.ui.close()
	game.player.set_control_locked(true)
	game.enemy.position = ApartmentWorld.iso(Vector2(800, 650))
	check("enemy physical route into bedroom", await enemy_reaches(Vector2(370, 320)))
	check("enemy physical route into kitchen", await enemy_reaches(Vector2(1350, 1400)))
	game.player.position = ApartmentWorld.iso(Vector2(580, 800))
	game.enemy.position = ApartmentWorld.iso(Vector2(660, 800))
	game.enemy.grace = 0.0
	game.enemy.facing = game.enemy.position.direction_to(game.player.position)
	check("wall blocks enemy vision", not game.enemy.sees_player())
	game.player.position = game.enemy.position + Vector2(40, 0)
	check("enemy sees nearby visible player", game.enemy.sees_player())
	game.player.position = ApartmentWorld.iso(Vector2(810, 75))
	game.enemy.position = ApartmentWorld.iso(Vector2(350, 1300))
	check("stealth exit without stun", game.can_escape())
	game.flashlight.toggle_flashlight(false)
	game.hidden_player = true
	check("hiding blocks vision", not game.enemy.sees_player())
	game.hidden_player = false
	game.fail_encounter()
	check("capture offers checkpoint retry", game.ui.modal_kind == "failure")
	game.ui.close()
	game.retry_checkpoint()
	check("failed encounter restores exact checkpoint stress", is_equal_approx(root.get_node("ParanoiaManager").target_paranoia, float(game.state.checkpoint.stress)))
	game.ui.close()
	interact("rope")
	game.begin_encounter()
	game.ui.close()
	game.enemy.position = ApartmentWorld.iso(Vector2(850, 325))
	game.player.position = game.enemy.position + Vector2(60, 0)
	interact("coat_trap")
	check("environment stuns without gear", game.enemy.mode == ApartmentEnemy.Mode.STUNNED and game.state.has("coat_trap"))
	check("fallen hanger cannot be farmed", not game._target_available("coat_trap"))
	check("nonlethal path without pepper/flashlight", game.resolve_enemy("restrained"))
	game.ui.close()
	game.retry_checkpoint()
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	# Persist a known state then exercise actual scene transition from the menu.
	root.get_node("SaveManager").save_game("chapter_test")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	root.get_node("SaveManager").load_game("chapter_test")
	await process_frame
	await process_frame
	game = current_scene
	while game.intro_active: await process_frame
	check("load from menu enters chapter", game.scene_file_path == ApartmentState.SCENE and game.state.has("phone_ready"))
	check("paranoia remains nondecaying after menu load", not root.get_node("ParanoiaManager").is_decay_active)
	check("historical file preserved byte for byte", FileAccess.get_file_as_string(legacy_path) == legacy_bytes)
	# Exercise proximity selection and the real UI buttons, without directly granting tutorial items.
	game.ui.close()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	current_scene._start_fresh_game()
	await process_frame
	await create_timer(1.65).timeout
	game = current_scene
	while game.intro_active: await process_frame
	while game.ui.modal_kind == "message": game.ui.advance_message()
	var interact_event: InputEventAction = InputEventAction.new()
	interact_event.action = "interact"
	interact_event.pressed = true
	game._update_target()
	check("spawn selects searchable bed", game.selected == "bed")
	game._unhandled_input(interact_event)
	game._update_target()
	check("search selects revealed blister", game.selected == "pills")
	game._unhandled_input(interact_event)
	var inventory_event: InputEventAction = InputEventAction.new()
	inventory_event.action = "toggle_inventory"
	inventory_event.pressed = true
	game.ui._input(inventory_event)
	for child: Node in game.ui.content.find_children("*", "Button", true, false):
		if child is Button and child.text == "Принять одну таблетку":
			child.pressed.emit()
			break
	check("complete tutorial through proximity/UI", game.state.has("dose") and root.get_node("InventoryManager").get_item_count("pills") == 1 and game.ui.modal_kind.is_empty())
	await process_frame
	check("objective card under five percent of screen", game.ui.goal_panel.size.x * game.ui.goal_panel.size.y < game.ui.root.size.x * game.ui.root.size.y * 0.05)
	check("no persistent full-width controls", not game.ui.controls.visible)
	check("HUD buttons readable", game.ui.inventory_button.size.x > 100 and game.ui.journal_button.size.x > 100)
	game.ui.message("Даша", "Короткая реплика, которая не закрывает квартиру.")
	await process_frame
	check("dialogue occupies less than one third", game.ui.modal.size.y < game.ui.root.size.y / 3.0)
	check("dialogue locks physics", not game.player.is_physics_processing())
	game.ui.advance_message()
	check("dialogue restores physics", game.player.is_physics_processing())
	game.ui.inventory()
	await process_frame
	check("inventory fits viewport", game.ui.modal.get_global_rect().end.x < game.ui.root.size.x and game.ui.modal.get_global_rect().end.y < game.ui.root.size.y)
	game.ui.close()
	game.state.documents.append("bedside")
	game.ui.document("bedside", true)
	var back: Button = game.ui.content.get_child(game.ui.content.get_child_count() - 1)
	back.pressed.emit()
	check("document back returns to journal", game.ui.modal_kind == "journal")
	game.ui.close()
	var overlapping_props: bool = false
	for i: int in game.world.obstacles.size():
		for j: int in range(i + 1, game.world.obstacles.size()):
			if game.world.obstacles[i].intersects(game.world.obstacles[j]): overlapping_props = true
	check("solid furniture footprints do not intersect", not overlapping_props)
	check("rug stays below actors and furniture", game.world.get_node("Rug").z_index < 0)
	var depth_pieces: int = 0
	for child: Node in game.world.get_children():
		if child.has_meta("prop_id") and child.get_meta("prop_id") == &"Bed": depth_pieces += 1
	check("large bed has multiple ground-depth pieces", depth_pieces > 10)
	check("mutual actor collision layers", game.player.collision_mask & 2 != 0)
	game.state.phase = "encounter"
	game._spawn_enemy()
	game.enemy.set_physics_process(false)
	game.enemy.position = ApartmentWorld.iso(Vector2(800, 800))
	game.player.position = game.enemy.position - Vector2(70, 0)
	Input.action_press("move_right")
	for i: int in 45: await physics_frame
	Input.action_release("move_right")
	check("player cannot walk through enemy", game.player.position.x < game.enemy.position.x and game.player.position.distance_to(game.enemy.position) >= 24.0)
	print("CHAPTER_CHECKS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
