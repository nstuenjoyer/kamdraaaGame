extends SceneTree

var failures: int = 0
var game: Node2D

func _initialize() -> void: call_deferred("run")

func check(title: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + title)
	if not ok: failures += 1

func actually_visible(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	if not Rect2(Vector2.ZERO,game.ui.root.size).encloses(rect): return false
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Control:
			if not parent.visible: return false
			if parent.clip_contents and not parent.get_global_rect().encloses(rect): return false
		parent = parent.get_parent()
	return true

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("KAMDRAAA_UI_CAPTURE_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://AI/review/images/ui")
	DirAccess.make_dir_recursive_absolute(output)
	check(filename + " captured", root.get_texture().get_image().save_png(output.path_join(filename + ".png")) == OK)

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.godot/chapter-check-"):
		push_error("Use isolated chapter-check APPDATA")
		quit(1)
		return
	change_scene_to_file("res://scenes/chapter_1/apartment.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.skip_intro()
	await process_frame
	await process_frame
	await process_frame
	game.set_process(false)
	var inventory: Node = root.get_node("InventoryManager")
	for id: String in ["pills", "flashlight", "phone", "front_key", "cabinet_key", "screwdriver", "fuse", "pepper", "throwable", "rope", "heavy"]:
		inventory.add_item(id, {"pills": "Седативное", "flashlight": "Фонарик", "phone": "Мобильный телефон", "front_key": "Ключ от входной двери", "cabinet_key": "Ключ от шкафа", "screwdriver": "Отвёртка", "fuse": "Предохранитель", "pepper": "Перцовый баллончик", "throwable": "Керамическая ваза", "rope": "Бельевой шнур", "heavy": "Чугунная сковорода"}[id], 2 if id == "pills" else 1, "", "Описание предмета для проверки полноты интерфейса.", id == "pills")
	game.ui.inventory("pills")
	await process_frame
	await process_frame
	check("inventory stays in viewport with eleven items", Rect2(Vector2.ZERO, game.ui.root.size).encloses(game.ui.modal.get_global_rect()))
	var selected: Control = root.gui_get_focus_owner()
	check("selected inventory tile owns focus", selected is Button and selected.tooltip_text == "Седативное")
	var dose: Button
	for entry: Node in game.ui.content.find_children("*", "Button", true, false):
		if entry.text == "Принять одну таблетку": dose = entry
	check("dose action visible without scrolling item list", dose != null and actually_visible(dose))
	await capture("15-full-inventory")
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	check("Tab traverses focus inside inventory", root.gui_get_focus_owner() != selected and game.ui.modal_kind == "inventory")
	var journal: InputEventAction = InputEventAction.new()
	journal.action = "toggle_clues"
	journal.pressed = true
	game.ui._input(journal)
	check("journal shortcut switches directly from inventory", game.ui.modal_kind == "journal")
	var map: InputEventAction = InputEventAction.new()
	map.action = "toggle_mind_palace"
	map.pressed = true
	game.ui._input(map)
	check("map shortcut switches directly from journal", game.ui.modal_kind == "map")
	game.ui.apartment_map()
	var bag: InputEventAction = InputEventAction.new()
	bag.action = "toggle_inventory"
	bag.pressed = true
	game.ui._input(bag)
	check("inventory shortcut switches directly from map", game.ui.modal_kind == "inventory")
	game.ui.document_scale = 29
	game.ui.document("diary", true)
	await process_frame
	await process_frame
	var last: Control = game.ui.content.get_child(game.ui.content.get_child_count()-1)
	check("document decision footer stays visible at large text size", actually_visible(last))
	await capture("16-document-large-text")
	game.ui.pause()
	check("pause starts with meaningful resume focus", root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text == "Продолжить игру")
	await capture("17-pause-focus")
	game.ui.close()
	game.ui._process(0)
	check("one goal location while announced", game.ui.goal_notice.visible and not game.ui.goal_panel.visible)
	inventory.reset_inventory()
	game.ui.inventory()
	await process_frame
	check("empty inventory remains navigable", game.ui.modal_kind == "inventory" and game.ui.dismiss_button.visible)
	game.ui.close()
	game.ui.begin_qte()
	await process_frame
	var assist: Button
	for node: Node in game.ui.content.find_children("*", "Button", true, false):
		if node.text.begins_with("Помощь"): assist = node
	assist.grab_focus()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	enter.pressed = false
	root.push_input(enter)
	await process_frame
	check("QTE assistance is reachable with keyboard Enter", game.ui.qte_assist)
	game.ui.close()
	print("UI_LAYOUT_CHECK failures=", failures)
	quit(0 if failures == 0 else 1)
