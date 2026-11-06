extends SceneTree

var failures: int = 0
var manager: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func settle_3d() -> Node:
	for i: int in 120:
		await physics_frame
		if current_scene != null and current_scene.scene_file_path == manager.CHAPTER_3D_SCENE and current_scene.navigation_ready:
			return current_scene
	return null

func run() -> void:
	manager = root.get_node("SaveManager")
	DirAccess.make_dir_recursive_absolute(manager.SAVES_DIR)
	var legacy: String = manager.SAVES_DIR + "slot_1.json"
	var file: FileAccess = FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string("legacy 2D fixture must remain unchanged")
	file.close()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	check(not manager.has_any_save(), "old 2D saves never enable 3D Continue")
	check(not manager.get_save_info("slot_1").get("compatible", true), "legacy slot marked incompatible")
	current_scene._on_new_game_pressed()
	var host: Node = await settle_3d()
	check(host != null, "actual menu New Game launches 3D")
	if host == null: quit(1); return
	host.ui.close()
	for i: int in 5: await physics_frame
	check(manager.save_game("slot_1"), "central manager writes v4 in 3D")
	check(manager.get_slot_path("slot_1") == host.save_path("slot_1"), "menu and chapter use identical isolated save path")
	check(manager.get_save_info("slot_1").get("compatible", false), "menu metadata accepts v4")
	check(not manager.save_game("../escape") and not manager.load_game("../escape"), "slot path whitelist")
	var saved: Vector3 = host.player.position
	host.player.position += Vector3(0.2,0,0)
	check(manager.load_game("slot_1") and host.player.position.is_equal_approx(saved), "in-scene load restores XYZ")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	check(manager.has_any_save() and manager.get_latest_save_slot() == "slot_1", "Continue selects latest compatible 3D slot")
	current_scene._on_continue_pressed()
	host = await settle_3d()
	check(host != null and manager.pending_save_data.is_empty() and host.player.position.distance_to(saved)<0.02, "menu Continue restores v4 after navigation and physics ready")
	check(FileAccess.get_file_as_string(legacy) == "legacy 2D fixture must remain unchanged", "old 2D file preserved byte for byte")
	print("3D ENTRY failures=", failures)
	quit(1 if failures else 0)
