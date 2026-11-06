extends SceneTree

var host: Node
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func run() -> void:
	host = load("res://scenes/chapter_1_3d/apartment.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	while not host.navigation_ready: await physics_frame
	check(host.intro_active and host.player.control_locked and not host.state.has("opening_done"), "opening holds movement and tutorial completion")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var folder: String = OS.get_environment("KAMDRAAA_3D_CAPTURE_DIR")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder.path_join("opening_title.png"))
	var stages: Dictionary = {}
	Engine.time_scale = 32
	for i: int in 20000:
		await process_frame
		if host.ui.intro_caption != null and host.ui.intro_caption.visible:
			stages[host.ui.intro_caption.text] = true
		if not host.intro_active: break
	Engine.time_scale = 1
	check(stages.size() == 3, "all three cinematic captions play without skipping")
	check(not host.state.has("opening_done") and host.ui.modal_kind == "message", "opening dialogue follows cinematic")
	var illusion_seen: bool = false
	for i: int in 20:
		if host.opening.silhouette.visible: illusion_seen = true
		if host.state.has("opening_done"): break
		host.ui.advance_message()
	check(illusion_seen and not host.opening.silhouette.visible, "illusion is shown then revealed as a coat")
	check(host.state.has("opening_done") and not host.player.control_locked and host.ui.hud.visible, "normal completion restores HUD and control")
	check(not host.state.has("dose") and root.get_node("InventoryManager").get_item_count("pills") == 0, "opening does not bypass bed search or first dose")
	for i: int in 5: await physics_frame
	check(host.save_slot("slot_1"), "completed opening can be saved")
	# Begin another real cinematic, then load while it awaits its title timer.
	host.state.flags.erase("intro")
	host.state.flags.erase("opening_done")
	host.intro_skip_requested = false
	host.opening.play()
	await process_frame
	check(host.load_slot("slot_1"), "load during opening succeeds")
	for i: int in 8: await process_frame
	check(not host.intro_active and host.ui.modal_kind.is_empty() and host.state.has("opening_done"), "cancelled cinematic cannot resume over a loaded save")
	print("3D OPENING failures=", failures)
	quit(1 if failures else 0)
