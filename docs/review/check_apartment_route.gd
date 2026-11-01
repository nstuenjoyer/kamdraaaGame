extends SceneTree

var game: Node2D
var failures: int = 0
var checks: int = 0
var travelled: float = 0.0

func _initialize() -> void: call_deferred("run")

func check(label: String, value: bool) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func dismiss() -> void:
	while game.ui.modal_kind == "message": game.ui.advance_message()
	if not game.ui.modal_kind.is_empty(): game.ui.close()

func walk_to(target: Vector2) -> bool:
	var path: PackedVector2Array = game.world.route(game.player.position, target)
	for tick: int in 2200:
		while not path.is_empty() and game.player.position.distance_to(path[0]) < 18: path.remove_at(0)
		if path.is_empty(): break
		var direction: Vector2 = game.player.position.direction_to(path[0])
		Input.action_press("move_right", maxf(0, direction.x))
		Input.action_press("move_left", maxf(0, -direction.x))
		Input.action_press("move_down", maxf(0, direction.y))
		Input.action_press("move_up", maxf(0, -direction.y))
		var before: Vector2 = game.player.position
		await physics_frame
		travelled += before.distance_to(game.player.position)
	for action: String in ["move_right", "move_left", "move_up", "move_down"]: Input.action_release(action)
	game.player.velocity = Vector2.ZERO
	return game.player.position.distance_to(target) < 83

func use(id: String) -> void:
	dismiss()
	var target: Node2D = game.world.interactables[id]
	check("walk to " + id, await walk_to(target.position))
	game._update_target()
	check("context selects " + id, game.selected == id)
	game.interact(id)

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().contains("/.godot/chapter-check-"):
		push_error("Use tools/run_chapter_checks.ps1 -Route")
		quit(1)
		return
	change_scene_to_file(ApartmentState.SCENE)
	await process_frame
	await process_frame
	await create_timer(1.65).timeout
	game = current_scene
	while game.intro_active: await process_frame
	dismiss()
	game.interact("bed")
	game.interact("pills")
	game.ui.inventory()
	root.get_node("InventoryManager").use_item("pills")
	game.ui.close()
	await process_frame
	check("tutorial complete before route starts", game.state.has("dose") and root.get_node("InventoryManager").get_item_count("pills") == 1)
	if not game.state.has("dose"):
		quit(1)
		return
	check("new plan has ten distinct spaces", game.world.ROOMS.size() == 10)
	check("front key is not loose on floor", not game.world.interactables.front_key.visible)
	check("study starts locked", not game.state.has("study_unlocked") and game.world.get_node("StudyDoor").collision_layer == 1)
	game.interact("front_key")
	check("cannot collect cabinet key before puzzle", not game.state.has("front_key"))
	game.ui.close()
	Engine.time_scale = 5.0
	Engine.physics_ticks_per_second = 120
	await use("exit")
	check("exit establishes missing key and stuck bolt", game.state.has("exit_checked"))
	await use("jacket")
	check("pocket note retained in journal", game.state.documents.has("pocket_note"))
	await use("key_rack")
	check("study key collected from key rack", game.state.has("study_key"))
	await use("study_door")
	dismiss()
	check("both office access points open", game.world.get_node("StudyDoor").collision_layer == 0 and game.world.get_node("StudySideDoor").collision_layer == 0)
	await use("desk_note")
	await use("key_cabinet")
	check("safe is a dedicated puzzle", game.ui.modal_kind == "cabinet")
	game.story.pin.assign([2, 1, 4, 0])
	check("misleading clock code fails safely", not game.story.try_pin() and not game.state.has("front_key"))
	check("wrong-code feedback visible inside panel", not game.story.pin_error.is_empty() and game.ui.modal_kind == "cabinet")
	await use("wall_clock")
	await use("microwave")
	await use("service_log")
	check("three contextual clues collected", game.state.documents.has("clock_note") and game.state.documents.has("outage_note") and game.state.documents.has("service_log"))
	await use("key_cabinet")
	game.story.active_digit = 0
	for digit: int in [2, 1, 1, 7]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = (KEY_0 + digit) as Key
		key.pressed = true
		game.ui._input(key)
	check("combination accepts actual keyboard digits", game.story.pin == [2, 1, 1, 7])
	check("deduced time opens cabinet", game.story.try_pin())
	check("cabinet grants exactly one front key", root.get_node("InventoryManager").get_item_count("front_key") == 1)
	check("cabinet points to diary without placing floor loot", game.state.documents.has("cabinet_note") and not game.world.interactables.diary.visible)
	await use("sofa_search")
	check("searching actual sofa reveals diary", game.state.has("sofa_searched") and game.state.documents.has("diary"))
	dismiss()
	game.choose_diary("trust")
	await use("screwdriver")
	await use("exit")
	check("real exit requires mechanical bolt puzzle", game.ui.modal_kind == "latch" and not game.state.has("coat"))
	check("wrong bolt alignment does not start encounter", not game.story.try_latch() and not is_instance_valid(game.enemy))
	game.story.latch.assign([2, 0, 1])
	check("aligned bolt opens", game.story.try_latch())
	dismiss()
	game.interact("exit")
	check("coat starts only after investigation and bolt", game.ui.modal_kind == "qte")
	for i: int in 10: game.ui.qte_press("move_left" if i % 2 == 0 else "move_right")
	game.ui._process(0.01)
	dismiss()
	check("coat reveal checkpoint has the investigation", game.state.has("coat") and game.state.checkpoint.chapter.flags.get("cabinet_unlocked", false))
	check("power and phone remain optional", not game.state.has("power") and not game.state.has("phone_ready"))
	game.begin_encounter()
	dismiss()
	game.enemy.position = ApartmentWorld.iso(Vector2(1320, 2070))
	game.enemy.set_physics_process(false)
	check("stealth option survives new route", game.can_escape())
	game.finish_scene("stealth")
	check("new route has an actual outcome", game.state.outcome == "stealth")
	dismiss()
	game.retry_checkpoint()
	check("checkpoint preserves solved puzzles", game.state.has("study_unlocked") and game.state.has("cabinet_unlocked") and game.state.has("latch_released"))
	# Optional electrical branch: failed settings do not destroy the unique insert.
	await use("fuse")
	await use("fusebox")
	check("repair presents circuit choice", game.ui.modal_kind == "repair")
	game.story.breakers.assign([true, true, true])
	check("shorted bath circuit rejects switch-on", not game.story.try_power() and root.get_node("InventoryManager").has_item("fuse"))
	game.story.breakers.assign([true, true, false])
	check("working circuits restore power", game.story.try_power() and game.state.has("power"))
	dismiss()
	check("new layout saves", root.get_node("SaveManager").save_game("route_check"))
	check("new layout loads and keeps office open", root.get_node("SaveManager").load_game("route_check") and game.world.study_open)
	var old_layout: Dictionary = game.export_chapter_save().duplicate(true)
	old_layout.erase("layout_revision")
	check("old apartment layout labelled incompatible", not ApartmentState.valid(old_layout))
	check("route is spatially larger than one short room visit", travelled > 6500)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("APARTMENT_ROUTE checks=%d failures=%d travelled=%.0f" % [checks, failures, travelled])
	quit(1 if failures else 0)
