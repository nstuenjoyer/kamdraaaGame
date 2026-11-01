extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(label: String, result: bool) -> void:
	print(("PASS " if result else "FAIL ") + label)
	if not result:
		failures += 1
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/review/images/tutorial")
	root.get_texture().get_image().save_png("res://docs/review/images/tutorial/" + name + ".png")
func run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var tutorial: Node = current_scene.get_node("Tutorial")
	var pills: Node = current_scene.get_node("Pills")
	var phone: Node = current_scene.get_node("QuestItem")
	var ui: Node = current_scene.get_node("UI")
	var manager: Node = root.get_node("ParanoiaManager")
	var inventory: Node = root.get_node("InventoryManager")
	var saves: Node = root.get_node("SaveManager")
	check("pills hidden at start", not pills.visible)
	await capture("phone")
	pills.pick_up_pills()
	check("early pickup blocked", not inventory.has_item("pills"))
	tutorial.search_bed()
	check("early search blocked", not ui.is_active)
	phone.answer_phone()
	var previous: float = manager.target_paranoia
	while ui.is_active:
		ui._show_next_line()
		check("call increases stress", manager.target_paranoia >= previous)
		previous = manager.target_paranoia
	check("call ends at maximum", manager.get_paranoia() == 100.0 and tutorial.stage == 1)
	check("pills remain hidden after call", not pills.visible)
	await capture("panic-search")
	manager._process(30.0)
	check("stress held for learning", manager.get_paranoia() == 100.0)
	tutorial.search_bed()
	ui.cancel_dialogue()
	check("cancelled search grants nothing", tutorial.stage == 1 and not pills.visible)
	tutorial.search_bed()
	ui._close_dialogue()
	check("search reveals pills", tutorial.stage == 2 and pills.visible)
	await capture("pills-revealed")
	check("save tutorial", saves.save_game("tutorial_probe"))
	pills.pick_up_pills()
	ui._close_dialogue()
	check("pickup teaches inventory", tutorial.stage == 3 and inventory.get_item_count("pills") == 3)
	current_scene.get_node("InventoryDialog").open_inventory()
	await capture("inventory")
	current_scene.get_node("InventoryDialog")._on_use_pressed()
	check("pill completes lesson", tutorial.stage == 4 and manager.get_paranoia() == 60.0 and inventory.get_item_count("pills") == 2)
	saves.load_game("tutorial_probe")
	check("load restores search progress", tutorial.stage == 2 and pills.visible and not inventory.has_item("pills"))
	saves.delete_save("tutorial_probe")
	saves.delete_save("autosave")
	print("TUTORIAL_RESULT failures=", failures)
	quit(1 if failures else 0)
