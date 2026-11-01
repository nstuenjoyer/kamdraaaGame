extends SceneTree

var output_directory: String = ""
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(title: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + title)
	if not passed: failures += 1

func capture(filename: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	check(filename + " saved", root.get_texture().get_image().save_png(output_directory + filename + ".png") == OK)
	print("CAPTURE ", filename)

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-"):
		push_error("Use isolated APPDATA under .godot/chapter-check-*")
		quit(1)
		return
	output_directory = OS.get_environment("KAMDRAAA_UI_CAPTURE_DIR")
	if output_directory.is_empty(): output_directory = ProjectSettings.globalize_path("res://AI/review/images/ui/")
	output_directory = output_directory.trim_suffix("/") + "/"
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		push_error("Cannot create screenshot output directory")
		quit(1)
		return
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var menu: Control = current_scene
	await capture("01-menu")
	check("main menu focuses play", root.gui_get_focus_owner() == menu.btn_play)
	menu.btn_settings.pressed.emit()
	await capture("02-settings")
	check("settings owns keyboard focus", menu.settings_dialog.is_ancestor_of(root.gui_get_focus_owner()))
	menu._switch_settings_tab("controls")
	await capture("03-controls")
	menu._on_load_pressed()
	await capture("04-load")
	check("sample save button hidden", not menu.btn_restore_saves.visible)
	menu._on_about_pressed()
	await capture("05-about")
	menu._close_all_modals(true)
	menu._start_fresh_game()
	await process_frame
	await process_frame
	var game: Node2D = current_scene
	while game.intro_active: await process_frame
	await capture("06-dialogue")
	while game.ui.modal_kind == "message": game.ui.advance_message()
	game.set_process(false)
	game.state.mark("opening_done")
	game.ui._process(0)
	game.ui.notify("Найдена записка. Она сохранена в дневнике.")
	await capture("07-hud")
	var inventory: Node = root.get_node("InventoryManager")
	inventory.add_item("pills", "Таблетки", 2, "", "Снижают тревогу на 40 пунктов. В блистере осталось две дозы.", true)
	inventory.add_item("flashlight", "Фонарик", 1, "", "Помогает осматривать тёмные комнаты.")
	inventory.add_item("screwdriver", "Отвёртка", 1, "", "Подходит к винтам на крышке щитка.")
	game.ui.inventory("pills")
	await capture("08-inventory")
	check("inventory remains within viewport", Rect2(Vector2.ZERO, game.ui.root.size).encloses(game.ui.modal.get_global_rect()))
	check("inventory has exactly one usable dose action", game.ui.content.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return node.text == "Принять одну таблетку").size() == 1)
	game.ui.journal()
	await capture("09-journal")
	game.ui.document("bedside")
	await capture("10-document")
	game.ui.apartment_map()
	await capture("11-map")
	game.ui.pause()
	await capture("12-pause")
	game.ui.settings()
	await capture("13-game-settings")
	game.ui.begin_qte()
	await capture("14-qte")
	game.ui.close()
	print("UI_CHECK ", "PASSED" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
