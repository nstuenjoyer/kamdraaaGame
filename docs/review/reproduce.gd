extends SceneTree
var SaveManager: Node
var ClueManager: Node
var InventoryManager: Node
var SettingsManager: Node
var ParanoiaManager: Node
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(label: String, condition: bool) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	# This suite writes settings and deletes its autosave. Keep real player data separate.
	var test_root: String = ProjectSettings.globalize_path("res://.godot/review-").replace("\\", "/").to_lower()
	if not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root):
		push_error("Use tools/run_review_checks.ps1 with isolated .godot/review-* user data")
		quit(1)
		return
	SaveManager = root.get_node("SaveManager")
	ClueManager = root.get_node("ClueManager")
	InventoryManager = root.get_node("InventoryManager")
	SettingsManager = root.get_node("SettingsManager")
	ParanoiaManager = root.get_node("ParanoiaManager")
	check("no fabricated saves", not SaveManager.has_any_save())
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames()
	ClueManager.discover_clue("receipt")
	ClueManager.discover_clue("mirror")
	ClueManager.connect_clues("receipt", "mirror")
	current_scene._start_fresh_game()
	await frames()
	check("R1 new game resets clues and deductions", ClueManager.get_discovered_count() == 0 and ClueManager.get_unlocked_deductions_count() == 0)
	check("new game enters apartment chapter", current_scene.scene_file_path == "res://scenes/chapter_1/apartment.tscn")
	# The remaining fixtures intentionally exercise the retained tech-demo mechanics.
	change_scene_to_file("res://scenes/main.tscn")
	await frames()
	var pills: Node = current_scene.get_node("Pills")
	# Pickup regression fixture: the search has already revealed the blister.
	current_scene.get_node("Tutorial").apply_stage(2)
	check("save before pickup", SaveManager.save_game("review_before"))
	pills.pick_up_pills()
	await frames()
	current_scene.get_node("UI").cancel_dialogue()
	check("load before pickup", SaveManager.load_game("review_before"))
	check("R2 pickup restored", not pills.picked_up and pills.visible and not InventoryManager.has_item("pills"))
	pills.pick_up_pills()
	current_scene.get_node("UI").cancel_dialogue()
	check("save after pickup", SaveManager.save_game("review_after"))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames()
	check("historical save rejected from menu", not SaveManager.load_game("review_after"))
	change_scene_to_file("res://scenes/main.tscn")
	await frames()
	SaveManager.load_game("review_after")
	await frames()
	check("R2 no duplicate pickup after legacy fixture reload", current_scene.get_node("Pills").picked_up and InventoryManager.get_item_count("pills") == 3)
	var phone: Node = current_scene.get_node("QuestItem")
	current_scene.get_node("Tutorial").apply_stage(0)
	phone.answer_phone()
	check("phone dialogue starts", current_scene.get_node("UI").is_active)
	check("R3 reject mid-call save", not SaveManager.save_game("review_phone") and not SaveManager.save_exists("review_phone"))
	current_scene.get_node("UI")._close_dialogue()
	check("phone completion opens door", current_scene.get_node("Door").is_opened)
	check("save completed call", SaveManager.save_game("review_phone"))
	SaveManager.load_game("review_phone")
	check("R3 complete call restored", phone.is_phone_answered and current_scene.get_node("Door").is_opened)
	SettingsManager.save_settings()
	SettingsManager.rebind_action("move_up", KEY_Z)
	SettingsManager.revert_settings()
	check("R4 discard restores keys", SettingsManager.get_action_keycode("move_up") == KEY_W)
	SettingsManager.reset_keybinds_to_defaults()
	check("secondary arrows retained", InputMap.action_get_events("move_up").size() == 2)
	InventoryManager.add_item("probe", "probe", 1)
	check("R5 negative removal rejected", not InventoryManager.remove_item("probe", -2) and InventoryManager.get_item_count("probe") == 1)
	ClueManager.discover_clue("receipt")
	SaveManager.pending_save_data = {"version": 1, "quest": {}}
	SaveManager.apply_pending_save_if_any(current_scene)
	check("R6 legacy saves clear clues", ClueManager.get_discovered_count() == 0)
	current_scene.get_node("BarReceipt").interact()
	current_scene.get_node("UI").cancel_dialogue()
	check("R7 cancel grants no clue", not ClueManager.is_clue_discovered("receipt"))
	check("R8 rebind removes old key from action", _test_binding())
	ParanoiaManager.set_paranoia(80)
	paused = true
	ParanoiaManager._process(10)
	check("pause freezes stress", ParanoiaManager.get_paranoia() == 80)
	paused = false
	var anxiety: Node = current_scene.get_node("DarknessAnxiety")
	anxiety._is_in_darkness = true
	anxiety._was_in_darkness = true
	anxiety._is_player_in_dark_zone = true
	anxiety._on_dark_zone_body_exited(current_scene.get_node("Player"))
	anxiety._process(0)
	check("darkness exit does not instantly remove stress", ParanoiaManager.get_paranoia() == 80)
	check("invalid save rejected", not SaveManager._valid_save({"version": 2, "player": "broken"}))
	check("nested corrupt clues rejected", not SaveManager._valid_save({"version": 2, "clues": {"clues": {"receipt": "bad"}}}))
	check("corrupt inventory rejected", not SaveManager._valid_save({"version": 2, "inventory": {"pills": {"count": "bad"}}}))
	await _walls()
	for slot: String in ["review_before", "review_after", "review_phone", "autosave"]:
		SaveManager.delete_save(slot)
	print("REGRESSION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
func _test_binding() -> bool:
	SettingsManager.rebind_action("toggle_history", KEY_Z)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_H
	ev.pressed = true
	return not ev.is_action_pressed("toggle_history")
func _walls() -> void:
	var walls: Node = current_scene.get_node("Walls")
	for child: Node in walls.get_children():
		if child is CollisionPolygon2D:
			check("wall triangulation " + child.name, not Geometry2D.triangulate_polygon(child.polygon).is_empty())
		if child is LightOccluder2D:
			var collision_name: String = child.name.replace("_Occluder", "_Collision")
			var collider: CollisionPolygon2D = walls.get_node_or_null(collision_name)
			check("shadow footprint " + child.name, collider != null and child.occluder.polygon == collider.polygon)
	for face: Node in current_scene.get_node("FrontWalls").get_children():
		if face is Polygon2D:
			check("front wall triangulation " + face.name, not Geometry2D.triangulate_polygon(face.polygon).is_empty())
	await physics_frame
	var space: PhysicsDirectSpaceState2D = current_scene.get_world_2d().direct_space_state
	check("NW wall blocks physics", not space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(400, 290), Vector2(350, 200))).is_empty())
	var door: Node = current_scene.get_node("Door")
	door.close()
	await physics_frame
	await physics_frame
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(Vector2(770, 400), Vector2(800, 470))
	check("closed door blocks passage", not space.intersect_ray(ray).is_empty())
	door.open()
	await physics_frame
	await physics_frame
	check("open door permits passage", space.intersect_ray(ray).is_empty())
	check("open door removes shadow", not door.get_node("DoorOccluder").visible)
