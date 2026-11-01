extends SceneTree

var failures: int = 0
var checks: int = 0
var menu: Control
var tag: String = ""
const OUTPUT: String = "E:/kamdraaa-game/AI/review/images/frontend/"

func _initialize() -> void:
	call_deferred("run")

func check(title: String, ok: bool) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + tag + " " + title)
	if not ok: failures += 1

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	await process_frame
	await create_timer(0.25).timeout

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check("capture " + label, root.get_texture().get_image().save_png(OUTPUT + tag + "-" + label + ".png") == OK)

func inside(panel: Control) -> bool:
	return Rect2(Vector2.ZERO, menu.size).grow(0.5).encloses(panel.get_global_rect())

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-front"):
		push_error("Isolated APPDATA required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	tag = "%dx%d" % [root.size.x,root.size.y]
	print("FRONTEND_SIZE window=", root.size, " logical=",menu.size)
	check("initial play focus", root.gui_get_focus_owner() == menu.btn_play)
	await shot("menu")
	await key(KEY_DOWN)
	check("down to load",root.gui_get_focus_owner() == menu.btn_load)
	await key(KEY_DOWN)
	check("down to settings",root.gui_get_focus_owner() == menu.btn_settings)
	await key(KEY_UP)
	check("up to load",root.gui_get_focus_owner() == menu.btn_load)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check("enter opens settings", menu.settings_dialog.visible)
	check("settings bounds",inside(menu.settings_dialog))
	await shot("settings")
	await key(KEY_ESCAPE)
	check("close restores settings trigger", not menu.settings_dialog.visible and root.gui_get_focus_owner() == menu.btn_settings)
	await key(KEY_ENTER)
	var manager: Node = root.get_node("SettingsManager")
	var original_volume: float = manager.master_volume
	menu.slider_master.value = 80
	await process_frame
	check("editing marks dirty",menu._has_unsaved_settings)
	await key(KEY_ESCAPE)
	check("dirty close opens confirm",menu.settings_confirm_dialog.visible and not menu.settings_dialog.visible)
	check("confirm bounds",inside(menu.settings_confirm_dialog))
	await shot("confirm")
	await key(KEY_ESCAPE)
	check("cancel returns to settings with edit",menu.settings_dialog.visible and not menu.settings_confirm_dialog.visible and menu._has_unsaved_settings and is_equal_approx(manager.master_volume,0.8))
	await key(KEY_ESCAPE)
	menu.btn_discard_save.pressed.emit()
	await create_timer(0.25).timeout
	check("discard restores saved value",not menu.modal_backdrop.visible and not menu._has_unsaved_settings and is_equal_approx(manager.master_volume,original_volume))
	check("discard restores settings trigger",root.gui_get_focus_owner() == menu.btn_settings)
	await key(KEY_ENTER)
	menu.slider_master.value = 75
	await process_frame
	await key(KEY_ESCAPE)
	menu.btn_confirm_save.pressed.emit()
	await create_timer(0.25).timeout
	check("save accepts edit",not menu.modal_backdrop.visible and not menu._has_unsaved_settings and is_equal_approx(manager.master_volume,0.75))
	check("save restores settings trigger",root.gui_get_focus_owner() == menu.btn_settings)
	await key(KEY_ENTER)
	check("saved value survives reopening",is_equal_approx(menu.slider_master.value,75.0) and not menu._has_unsaved_settings)
	menu._switch_settings_tab("controls")
	await create_timer(0.25).timeout
	check("controls bounds",inside(menu.settings_dialog))
	await shot("controls")
	await key(KEY_ESCAPE)
	menu.btn_load.grab_focus()
	await key(KEY_ENTER)
	check("load bounds",menu.load_dialog.visible and inside(menu.load_dialog))
	await shot("load")
	await key(KEY_ESCAPE)
	check("load close restores trigger",root.gui_get_focus_owner() == menu.btn_load)
	menu.btn_about.grab_focus()
	await key(KEY_ENTER)
	check("about bounds",menu.about_dialog.visible and inside(menu.about_dialog))
	await shot("about")
	await key(KEY_ESCAPE)
	check("about close restores trigger",root.gui_get_focus_owner() == menu.btn_about)
	menu._open_modal(menu.play_dialog)
	await create_timer(0.25).timeout
	check("play bounds",inside(menu.play_dialog))
	await shot("play")
	await key(KEY_ESCAPE)
	print("FRONTEND_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
