class_name ApartmentUI
extends CanvasLayer

var host: Node2D
var root: Control
var modal: PanelContainer
var content: VBoxContainer
var objective: Label
var stress_label: Label
var stress_bar: ProgressBar
var prompt: Label
var toast: Label
var controls: Label
var modal_kind: String = ""
var toast_time: float = 0.0
var document_scale: int = 21
var rebind: String = ""
var qte_progress: float = 0.0
var qte_time: float = 0.0
var qte_next: String = "move_left"
var qte_assist: bool = false
var qte_paused: bool = false
var qte_label: Label
var qte_bar: ProgressBar
var hud: Control
var goal_panel: PanelContainer
var toast_panel: PanelContainer
var prompt_panel: PanelContainer
var inventory_button: Button
var journal_button: Button
var tool_row: HBoxContainer
var tool_buttons: Dictionary = {}
var notification_log: Array[String] = []
var message_pages: Array[String] = []
var message_page: int = 0
var message_title: String = ""
var message_after: Callable
var notification_queue: Array[Dictionary] = []
var intro_caption: Label
var heading: Label
var section_label: Label
var modal_header: HBoxContainer
var dismiss_button: Button
var navigation: HBoxContainer
var intro_skip_button: Button
var last_goal: String = ""
var goal_notice: PanelContainer
var goal_notice_text: Label
var goal_notice_time: float = 0.0
var folio: Control
var page_scroll: ScrollContainer
var content_body: Label
var body_is_paper: bool = false

func setup(controller: Node2D) -> void:
	host = controller
	name = "ChapterUI"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = NoirUI.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	goal_panel = card(hud, Vector2(32, 30), Vector2(310, 62))
	var goals: VBoxContainer = VBoxContainer.new()
	goal_panel.add_child(goals)
	add_label(goals, "ДНЕВНИК / ТЕКУЩАЯ ЦЕЛЬ", 10, NoirUI.ACCENT)
	objective = add_label(goals, "", 16)
	objective.max_lines_visible = 2
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var stress_panel: PanelContainer = card(hud, Vector2(32, -78), Vector2(168, 42), Vector2(0, 1))
	var stress: VBoxContainer = VBoxContainer.new()
	stress_panel.add_child(stress)
	stress_label = add_label(stress, "ТРЕВОГА", 13)
	stress_bar = ProgressBar.new()
	stress_bar.custom_minimum_size.y = 3
	stress_bar.show_percentage = false
	stress_bar.add_theme_stylebox_override("background", panel_style(Color("34372e"), 0))
	stress_bar.add_theme_stylebox_override("fill", panel_style(NoirUI.ACCENT, 0))
	stress.add_child(stress_bar)
	var shortcuts: HBoxContainer = HBoxContainer.new()
	shortcuts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	shortcuts.offset_left = -484
	shortcuts.offset_right = -24
	shortcuts.offset_top = -68
	shortcuts.offset_bottom = -24
	hud.add_child(shortcuts)
	journal_button = button("", func() -> void: journal(), shortcuts)
	inventory_button = button("", inventory, shortcuts)
	button("Esc · Меню", pause, shortcuts)
	toast_panel = card(hud, Vector2(-362, -196), Vector2(330, 94), Vector2(1, 1))
	var notice_style: StyleBoxFlat = NoirUI.surface(Color(0.07, 0.08, 0.065, 0.94), 14)
	notice_style.border_width_left = 2
	notice_style.border_color = NoirUI.ACCENT
	toast_panel.add_theme_stylebox_override("panel", notice_style)
	toast = add_label(toast_panel, "", 17, NoirUI.TEXT)
	toast.max_lines_visible = 4
	toast.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	toast_panel.visible = false
	goal_notice = card(hud, Vector2(32, 30), Vector2(310, 62))
	var goal_style: StyleBoxFlat = NoirUI.surface(Color(0.06, 0.075, 0.055, 0.94), 12)
	goal_style.border_width_left = 2
	goal_style.border_color = NoirUI.ACCENT
	goal_notice.add_theme_stylebox_override("panel", goal_style)
	goal_notice_text = add_label(goal_notice, "", 16, NoirUI.TEXT)
	goal_notice.visible = false
	prompt_panel = card(hud, Vector2.ZERO, Vector2(280, 42))
	prompt_panel.add_theme_stylebox_override("panel", NoirUI.surface(Color(0.055, 0.065, 0.05, 0.94), 10))
	prompt = add_label(prompt_panel, "", 17, NoirUI.TEXT)
	prompt.max_lines_visible = 2
	prompt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prompt_panel.visible = false
	tool_row = HBoxContainer.new()
	tool_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tool_row.offset_left = 248
	tool_row.offset_right = 790
	tool_row.offset_top = -68
	tool_row.offset_bottom = -24
	hud.add_child(tool_row)
	for action: String in ["use_tool", "throw_item", "blind"]:
		var callback: Callable = host.use_pepper if action == "use_tool" else host.blind_enemy
		if action == "throw_item": callback = func() -> void: host.throw_vase(host.get_global_mouse_position())
		tool_buttons[action] = button("", callback, tool_row)
		tool_buttons[action].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tool_buttons[action].custom_minimum_size.x = 112
	controls = Label.new()
	controls.visible = false
	hud.add_child(controls)
	for hint: Button in [journal_button, inventory_button]:
		hint.add_theme_font_size_override("font_size", 14)
	var shade: ColorRect = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.025, 0.03, 0.025, 0.77)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	root.add_child(shade)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", panel_style(NoirUI.INK, 32))
	modal.visible = false
	root.add_child(modal)
	folio = Control.new()
	folio.set_script(preload("res://scripts/chapter_1/folio_decoration.gd"))
	modal.add_child(folio)
	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	modal.add_child(shell)
	section_label = add_label(shell, "", 12, NoirUI.ACCENT)
	modal_header = HBoxContainer.new()
	shell.add_child(modal_header)
	heading = add_label(modal_header, "", 34)
	heading.add_theme_font_override("font", NoirUI.title_font())
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismiss_button = button("Esc   Закрыть", close, modal_header)
	dismiss_button.custom_minimum_size.x = 142
	dismiss_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	dismiss_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dismiss_button.add_theme_color_override("font_focus_color", NoirUI.TEXT)
	navigation = HBoxContainer.new()
	shell.add_child(navigation)
	button("Сумка", inventory, navigation)
	button("Дневник", journal, navigation)
	button("План квартиры", apartment_map, navigation)
	var divider: HSeparator = HSeparator.new()
	var rule: StyleBoxLine = StyleBoxLine.new()
	rule.color = NoirUI.LINE
	rule.thickness = 1
	divider.add_theme_stylebox_override("separator", rule)
	shell.add_child(divider)
	var scroll: ScrollContainer = ScrollContainer.new()
	page_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	root.resized.connect(_layout_modal)
	modal.minimum_size_changed.connect(_layout_modal)

func card(parent: Node, offset: Vector2, dimensions: Vector2, anchor: Vector2 = Vector2.ZERO) -> PanelContainer:
	var result: PanelContainer = PanelContainer.new()
	parent.add_child(result)
	result.anchor_left = anchor.x
	result.anchor_right = anchor.x
	result.anchor_top = anchor.y
	result.anchor_bottom = anchor.y
	result.offset_left = offset.x
	result.offset_top = offset.y
	result.offset_right = offset.x + dimensions.x
	result.offset_bottom = offset.y + dimensions.y
	result.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.035, 0.025, 0.42), 8))
	return result

func _layout_modal() -> void:
	if modal == null: return
	var available: Vector2 = root.size
	var dimensions: Vector2 = Vector2(560, 420)
	if modal_kind == "message": dimensions = Vector2(850, 208)
	elif modal_kind in ["cabinet", "latch", "repair"]: dimensions = Vector2(700, 520)
	elif modal_kind in ["document", "journal", "map", "settings", "inventory"]: dimensions = Vector2(1040, 616)
	elif modal_kind == "pause": dimensions = Vector2(820, 530)
	elif modal_kind == "loads": dimensions = Vector2(760, 602)
	elif modal_kind in ["qte", "qte_retry"]: dimensions = Vector2(620, 440)
	dimensions = dimensions.min(available - Vector2(48, 48))
	modal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	modal.position = (available - dimensions) * 0.5
	if modal_kind == "message": modal.position.y = available.y - dimensions.y - 26
	modal.size = dimensions
	# Setting offsets after a container's old minimum has grown can leave it too tall.
	modal.set_deferred("size", dimensions)

func panel_style(color: Color, padding: int = 16) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(padding)
	return style

func add_label(parent: Node, value: String, size_value: int = 20, color: Color = NoirUI.TEXT) -> Label:
	var result: Label = Label.new()
	result.text = value
	if body_is_paper and color == NoirUI.TEXT: color = Color("35382e")
	result.add_theme_font_size_override("font_size", size_value)
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("line_spacing", 5)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result

func button(text: String, action: Callable, parent: Node = null) -> Button:
	var result: Button = Button.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = 44
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", 17)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if body_is_paper:
		result.add_theme_color_override("font_color", Color("33382d"))
		result.add_theme_color_override("font_hover_color", NoirUI.TEXT)
		result.add_theme_color_override("font_focus_color", NoirUI.TEXT)
	result.mouse_entered.connect(SoundManager.play_hover)
	result.pressed.connect(SoundManager.play_click)
	result.pressed.connect(action)
	(content if parent == null else parent).add_child(result)
	return result

func open(kind: String, title: String, body: String = "") -> void:
	modal_kind = kind
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var paper: bool = kind in ["document", "journal"]
	body_is_paper = paper
	folio.paper = paper
	folio.queue_redraw()
	modal.add_theme_stylebox_override("panel", panel_style(NoirUI.PAPER if paper else NoirUI.INK, 18 if kind == "message" else 30))
	(modal.get_child(1) as VBoxContainer).add_theme_constant_override("separation", 8 if kind == "message" else 12)
	heading.text = title
	heading.add_theme_font_size_override("font_size", 19 if kind == "message" else 34)
	heading.add_theme_color_override("font_color", Color("292d25") if paper else NoirUI.TEXT)
	section_label.text = {"inventory": "ЛИЧНЫЕ ВЕЩИ", "journal": "ЗАПИСИ ДАШИ", "document": "НАЙДЕННАЯ ЗАПИСЬ", "map": "ОРИЕНТИРЫ", "pause": "ИГРА ПРИОСТАНОВЛЕНА", "settings": "ПАРАМЕТРЫ", "loads": "ПРОГРЕСС", "qte": "ДЕЙСТВУЙТЕ"}.get(kind, "ТЁМНАЯ КВАРТИРА")
	section_label.add_theme_color_override("font_color", Color("62604e") if paper else NoirUI.ACCENT)
	section_label.visible = kind not in ["message", "pause"]
	navigation.visible = kind in ["inventory", "journal", "map"]
	for index: int in navigation.get_child_count():
		var tab_button: Button = navigation.get_child(index) as Button
		tab_button.add_theme_stylebox_override("normal", NoirUI.tab_style(["inventory", "journal", "map"][index] == kind))
	dismiss_button.visible = kind not in ["message", "qte", "qte_retry", "ending", "failure"]
	dismiss_button.add_theme_color_override("font_color", Color("33382d") if paper else NoirUI.MUTED)
	dismiss_button.add_theme_color_override("font_focus_color", Color("33382d") if paper else NoirUI.TEXT)
	for child: Node in navigation.get_children():
		(child as Button).add_theme_color_override("font_color", Color("4c4d40") if paper else NoirUI.MUTED)
	if not body.is_empty():
		content_body = add_label(content, body, document_scale if kind == "document" else 18)
	_layout_modal()
	modal.visible = true
	content.get_parent().set_deferred("scroll_vertical", 0)
	if dismiss_button.visible: dismiss_button.grab_focus()
	hud.visible = false
	root.get_node("Shade").visible = kind != "message"
	host.player.set_control_locked(true)
	host.player.set_physics_process(false)
	host.player.velocity = Vector2.ZERO

func close() -> void:
	modal.visible = false
	hud.visible = true
	root.get_node("Shade").visible = false
	modal_kind = ""
	message_after = Callable()
	message_pages.clear()
	host.player.set_physics_process(true)
	rebind = ""
	get_tree().paused = false
	host.player.set_control_locked(host.intro_active or host.hidden_player)

func notify(message: String, duration: float = 5.0) -> void:
	if message.length() > 155:
		var cut: int = message.rfind(" ", 155)
		if cut > 0:
			notify(message.substr(0, cut), duration)
			notify(message.substr(cut + 1), duration)
			return
	if not toast.text.is_empty() and toast_time > 0:
		if toast.text != message and not notification_queue.any(func(entry: Dictionary) -> bool: return entry.text == message):
			if notification_queue.size() >= 4: notification_queue.pop_front()
			notification_queue.append({"text": message, "duration": duration})
		return
	toast.text = message
	toast_time = clampf(maxf(duration, message.length() / 19.0), 3.0, 12.0)
	toast_panel.visible = true
	notification_log.append(message)
	if notification_log.size() > 20: notification_log.pop_front()

func opening_fade() -> void:
	hud.visible = false
	var veil: ColorRect = ColorRect.new()
	veil.color = Color("080d13")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var caption: Label = add_label(veil, "АКТ I\nТЁМНАЯ КВАРТИРА", 42, Color("edf1e9"))
	caption.add_theme_font_override("font", NoirUI.title_font())
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 64
	caption.offset_right = -64
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_constant_override("line_spacing", 18)
	# Opaque from its first frame; the scene curtain covers construction beforehand.
	veil.modulate.a = 1.0
	if host.has_node("BootCurtain"): host.get_node("BootCurtain").queue_free()
	intro_skip_button = button("Пропустить вступление · Enter", host.skip_intro, root)
	intro_skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	intro_skip_button.offset_left = -360
	intro_skip_button.offset_right = -36
	intro_skip_button.offset_top = -78
	intro_skip_button.offset_bottom = -34
	await host._intro_wait(4.5)
	var elapsed: float = 0.0
	while elapsed < 1.2 and not host.intro_skip_requested:
		await get_tree().process_frame
		if not get_tree().paused: elapsed += get_process_delta_time()
		veil.modulate.a = 1.0 - clampf(elapsed / 1.2, 0.0, 1.0)
	veil.queue_free()

func hide_intro_skip() -> void:
	if is_instance_valid(intro_skip_button): intro_skip_button.queue_free()

func cinematic_caption(value: String) -> void:
	if intro_caption == null:
		intro_caption = add_label(root, "", 23, Color("e0e4dd"))
		intro_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		intro_caption.offset_left = 110
		intro_caption.offset_right = -110
		intro_caption.offset_top = -110
		intro_caption.offset_bottom = -32
		intro_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
		intro_caption.add_theme_constant_override("shadow_offset_x", 2)
		intro_caption.add_theme_constant_override("shadow_offset_y", 2)
	intro_caption.text = value
	intro_caption.visible = not value.is_empty()

func document(id: String, from_journal: bool = false) -> void:
	var data: Dictionary = host.documents.get(id, {})
	open("document", data.get("title", id))
	SoundManager.play_paper_rustle()
	var reading: HBoxContainer = HBoxContainer.new()
	reading.add_theme_constant_override("separation", 30)
	content.add_child(reading)
	var margin: VBoxContainer = VBoxContainer.new()
	margin.custom_minimum_size.x = 100
	reading.add_child(margin)
	add_label(margin, "ЛИЧНЫЙ\nАРХИВ", 11, Color("77705e"))
	var number: int = maxi(1, host.state.documents.find(id) + 1)
	add_label(margin, "%02d" % number, 38, Color("a19173")).add_theme_font_override("font", NoirUI.title_font())
	add_label(margin, "Сохранено\nв дневнике", 12, Color("77705e"))
	var reader: ScrollContainer = ScrollContainer.new()
	reader.custom_minimum_size.y = clampf(root.size.y - 458, 150, 262)
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading.add_child(reader)
	var page: Label = add_label(reader, str(data.get("text", "")), document_scale, Color("35382e"))
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_font_override("font", NoirUI.title_font())
	page.add_theme_constant_override("line_spacing", 8)
	var text_row: HBoxContainer = HBoxContainer.new()
	text_row.add_theme_constant_override("separation", 12)
	content.add_child(text_row)
	button("А−   Уменьшить", func() -> void: document_scale = maxi(17, document_scale - 2); document(id, from_journal), text_row)
	button("А+   Увеличить", func() -> void: document_scale = mini(29, document_scale + 2); document(id, from_journal), text_row)
	var decision: bool = id == "diary" and host.state.diary_choice.is_empty()
	var done: Button = button("Выбрать отношение к дневнику" if decision else "Прочитано · вернуться", func() -> void:
		close()
		if decision: diary_choice()
		elif from_journal: journal("documents")
	)
	_primary(done)
	done.grab_focus()
	button("Решить позже" if decision else "Назад", func() -> void:
		close()
		if from_journal: journal("documents")
	)

func diary_choice() -> void:
	open("choice", "Даша · кому верить?", "Записи сделаны моим почерком. Но я едва помню последние дни. Доверие этим словам усилит подозрения и дальнейшие искажения. Сам выбор не запрещает брать предметы.")
	button("Поверить дневнику · искать защиту", func() -> void: close(); host.choose_diary("trust"))
	button("Решить, что это шутка · проверить факты", func() -> void: close(); host.choose_diary("dismiss"))
	button("Подумать позже", close)

func journal(tab: String = "tasks") -> void:
	open("journal", "Дневник Даши")
	var spread: HBoxContainer = HBoxContainer.new()
	spread.add_theme_constant_override("separation", 34)
	content.add_child(spread)
	var index: VBoxContainer = VBoxContainer.new()
	index.custom_minimum_size.x = 185
	index.add_theme_constant_override("separation", 8)
	spread.add_child(index)
	add_label(index, "СОДЕРЖАНИЕ", 10, Color("80745e"))
	var tab_values: Array[String] = ["tasks", "route", "documents"]
	for n: int in tab_values.size():
		var title: String = ["01   Что делать", "02   Расследование", "03   Записи / %d" % host.state.documents.size()][n]
		var entry: Button = button(title, journal.bind(tab_values[n]), index)
		entry.custom_minimum_size.y = 48
		entry.add_theme_font_size_override("font_size", 16)
		entry.add_theme_stylebox_override("normal", NoirUI.tab_style(tab_values[n] == tab))
	add_label(index, "ГЛАВА ПЕРВАЯ\nТёмная квартира", 12, Color("80745e"))
	button("Как играть", help, index)
	var page: VBoxContainer = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	spread.add_child(page)
	if tab == "tasks":
		add_label(page, "СЕЙЧАС", 11, Color("80745e"))
		add_label(page, host.current_goal(), 28, Color("34392f")).add_theme_font_override("font", NoirUI.title_font())
		var details: String = host.goal_details()
		var goal: String = host.current_goal()
		if details.begins_with(goal + " — "): details = details.trim_prefix(goal + " — ")
		if not details.is_empty(): details = details.substr(0,1).to_upper() + details.substr(1)
		add_label(page, details, 18, Color("535744"))
		if host.state.has("dose"):
			add_label(page, "Можно заняться позже", 20, Color("6b6958")).add_theme_font_override("font", NoirUI.title_font())
			for option: Array in [["Свет в квартире", host.state.has("power"), "Отвёртка, предохранитель, щиток."], ["Зарядить телефон", host.state.has("phone_ready"), "Для зарядки нужно электричество."], ["Средство защиты", host.state.has("pepper"), "Осмотреть шкаф в прихожей."]]:
				add_label(page, ("✓   " if option[1] else "○   ") + option[0], 17, Color("69725c") if option[1] else Color("454b3d"))
				if not option[1]: add_label(page, "      " + str(option[2]), 13, Color("807b68"))
		else:
			add_label(page, "О самочувствии", 20, Color("6b6958")).add_theme_font_override("font", NoirUI.title_font())
			add_label(page, "Тревога усиливает искажения. Свет останавливает её рост, но не снимает накопленное напряжение.", 17, Color("535744"))
			add_label(page, "Одна таблетка снижает тревогу на 40 пунктов. Запас ограничен.", 17, Color("535744"))

	elif tab == "route":
		add_label(page, "Ход расследования", 26, Color("34392f")).add_theme_font_override("font", NoirUI.title_font())
		for entry: Dictionary in host.story.quest_log():
			add_label(page, ("✓   " if entry.complete else "○   ") + str(entry.text), 17, Color("7c806c") if entry.complete else Color("454b3d"))
	else:
		add_label(page, "Найденные записи", 26, Color("34392f")).add_theme_font_override("font", NoirUI.title_font())
		for id: String in host.state.documents:
			button("%02d   %s" % [host.state.documents.find(id) + 1, host.documents[id].title], document.bind(id, true), page)
		if host.state.documents.is_empty():
			illustration(page, "document", Vector2(120, 100), Color("8b8068"))
			add_label(page, "Здесь будут ваши находки", 21, Color("6b6958"))
			add_label(page, "Осмотренные записки сохраняются автоматически. Начните с листка у кровати.", 17, Color("807b68"))

func apartment_map() -> void:
	open("map", "План квартиры", "Даша отмечена точкой. Разрывы в стенах обозначают проходы между комнатами.")
	var view: Control = Control.new()
	view.set_script(preload("res://scripts/chapter_1/apartment_map.gd"))
	view.custom_minimum_size = Vector2(0, 300)
	view.world = host.world
	view.player_position = host.player.position
	content.add_child(view)

func illustration(parent: Node, item_id: String, dimensions: Vector2, tint: Color = NoirUI.ACCENT) -> Control:
	var image: Control = Control.new()
	image.set_script(preload("res://scripts/chapter_1/item_illustration.gd"))
	image.item_id = item_id
	image.ink = tint
	image.custom_minimum_size = dimensions
	parent.add_child(image)
	return image

func inventory(selected: String = "") -> void:
	open("inventory", "Личные вещи")
	var items: Array[Dictionary] = InventoryManager.get_all_items()
	if selected.is_empty() and not items.is_empty(): selected = str(items[0].id)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	content.add_child(columns)
	var items_column: VBoxContainer = VBoxContainer.new()
	items_column.custom_minimum_size.x = 480
	items_column.add_theme_constant_override("separation", 14)
	columns.add_child(items_column)
	add_label(items_column, "СОДЕРЖИМОЕ СУМКИ     /     %02d" % items.size(), 11, NoirUI.MUTED)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var item_scroll: ScrollContainer = ScrollContainer.new()
	item_scroll.custom_minimum_size = Vector2(480, 240 if root.size.y < 680 else 280)
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_column.add_child(item_scroll)
	item_scroll.add_child(grid)
	var first_tile: Button
	var selected_tile: Button
	for item: Dictionary in items:
		var tile: Button = button("", inventory.bind(str(item.id)), grid)
		tile.tooltip_text = str(item.name)
		tile.custom_minimum_size = Vector2(148, 116 if root.size.y < 680 else 130)
		tile.add_theme_stylebox_override("normal", _item_tile_style(item.id == selected))
		tile.add_theme_stylebox_override("hover", _item_tile_style(true))
		var inset: MarginContainer = MarginContainer.new()
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side: String in ["left", "top", "right", "bottom"]: inset.add_theme_constant_override("margin_" + side, 10)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(inset)
		var layout: VBoxContainer = VBoxContainer.new()
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(layout)
		illustration(layout, str(item.id), Vector2(0, 60 if root.size.y < 680 else 72), NoirUI.TEXT if item.id == selected else NoirUI.ACCENT)
		var title: Label = add_label(layout, str(item.name), 13, NoirUI.TEXT)
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count: Label = add_label(tile, str(item.count), 12, NoirUI.ACCENT)
		count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		count.position = Vector2(124, 8)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if first_tile == null: first_tile = tile
		if item.id == selected: selected_tile = tile
	for slot: int in maxi(0, 6 - items.size()):
		var empty: Panel = Panel.new()
		empty.custom_minimum_size = Vector2(148, 116 if root.size.y < 680 else 130)
		empty.add_theme_stylebox_override("panel", _item_tile_style(false, true))
		grid.add_child(empty)
	add_label(items_column, "Выберите предмет, чтобы осмотреть его", 13, NoirUI.MUTED)
	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", NoirUI.surface(Color("202729"), 16 if root.size.y < 680 else 22))
	columns.add_child(detail_panel)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.custom_minimum_size = Vector2(300, 320)
	detail.add_theme_constant_override("separation", 13)
	detail_panel.add_child(detail)
	var selection: Dictionary = InventoryManager.get_item(selected)
	if not selection.is_empty():
		add_label(detail, "ПРЕДМЕТ / %02d" % (items.find(selection) + 1), 10, NoirUI.MUTED)
		add_label(detail, str(selection.name), 27, NoirUI.TEXT).add_theme_font_override("font", NoirUI.title_font())
		illustration(detail, selected, Vector2(0, 90 if root.size.y < 680 else 122), NoirUI.TEXT)
		add_label(detail, str(selection.description), 17)
		if selected != "pills": add_label(detail, "Используется у подходящего объекта в квартире.", 13, NoirUI.MUTED)
	else:
		illustration(detail, "document", Vector2(0, 150), NoirUI.MUTED)
		add_label(detail, "Сумка пока пуста", 26, NoirUI.TEXT).add_theme_font_override("font", NoirUI.title_font())
		add_label(detail, "Осмотрите вещи в квартире. Найденные предметы будут здесь.", 17, NoirUI.MUTED)
	if selected == "pills":
		var use: Button = button("Принять одну таблетку", func() -> void:
			InventoryManager.use_item("pills")
			close()
		, detail)
		_primary(use)
	if selected_tile != null: selected_tile.grab_focus()
	elif first_tile != null: first_tile.grab_focus()

func _primary(action: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		action.add_theme_stylebox_override(state, NoirUI.primary_style(state))
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		action.add_theme_color_override(color, Color("21282b"))

func _item_tile_style(selected: bool, empty: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = NoirUI.surface(Color("283033") if selected else Color("171d1f"), 10)
	style.border_color = NoirUI.ACCENT if selected else Color("343c3d")
	style.set_border_width_all(1)
	if empty:
		style.bg_color = Color(0.07, 0.09, 0.095, 0.5)
		style.border_color = Color("262e30")
	return style

func message(title: String, body: String, after: Callable = Callable()) -> void:
	message_title = title
	message_after = after
	message_pages.clear()
	var page: String = ""
	for word: String in body.replace("\n", " ").split(" ", false):
		if page.length() + word.length() > 180 and not page.is_empty():
			message_pages.append(page)
			page = ""
		page += (" " if not page.is_empty() else "") + word
		if page.length() > 90 and (word.ends_with(".") or word.ends_with("?") or word.ends_with("!")):
			message_pages.append(page)
			page = ""
	if not page.is_empty(): message_pages.append(page)
	message_page = 0
	_show_message_page()
	SoundManager.play_dialogue_advance()

func _show_message_page() -> void:
	open("message", message_title, message_pages[message_page] if not message_pages.is_empty() else "")
	button("Продолжить · %s    %d/%d" % [key("interact"), message_page + 1, maxi(1, message_pages.size())], advance_message)

func advance_message() -> void:
	if message_page + 1 < message_pages.size():
		message_page += 1
		_show_message_page()
	else:
		var after: Callable = message_after
		close()
		if after.is_valid(): after.call()

func help() -> void:
	open("settings", "Как играть", "Движение: %s / %s / %s / %s\nВзаимодействие: %s · Фонарик: %s\nСумка: %s · Дневник: %s · План квартиры: %s\nКрасться: %s · Бежать: %s\n\nСтресс усиливает искажения и сам не уменьшается. Таблетка снимает 40 пунктов. Свет останавливает страх темноты.\n\nВо время встречи: %s — перец, %s — бросить вазу к курсору, %s — ослепить направленным фонариком." % [key("move_up"), key("move_left"), key("move_down"), key("move_right"), key("interact"), key("toggle_flashlight"), key("toggle_inventory"), key("toggle_clues"), key("toggle_mind_palace"), key("sneak"), key("run"), key("use_tool"), key("throw_item"), key("blind")])
	button("Назад в дневник", journal)

func pause() -> void:
	open("pause", "Пауза")
	get_tree().paused = true
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	content.add_child(columns)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.custom_minimum_size.x = 370
	actions.add_theme_constant_override("separation", 4)
	columns.add_child(actions)
	var resume: Button = button("Продолжить игру", close, actions)
	_primary(resume)
	button("Дневник", journal, actions)
	button("План квартиры", apartment_map, actions)
	button("Сохранить / загрузить", load_slots, actions)
	button("Звук и управление", settings, actions)
	button("Повторить контрольную точку", func() -> void: close(); host.retry_checkpoint(), actions)
	button("В главное меню", func() -> void: close(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), actions)
	var summary: VBoxContainer = VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 20)
	columns.add_child(summary)
	add_label(summary, "ГЛАВА ПЕРВАЯ", 11, NoirUI.ACCENT)
	add_label(summary, "Тёмная\nквартира", 30, NoirUI.TEXT).add_theme_font_override("font", NoirUI.title_font())
	add_label(summary, host.current_goal(), 17, NoirUI.MUTED)
	add_label(summary, "%02d   найденных записей\n%02d   предметов в сумке" % [host.state.documents.size(), InventoryManager.get_all_items().size()], 13, NoirUI.MUTED)
	resume.grab_focus()

func load_slots() -> void:
	open("loads", "Сохранения")
	for slot: String in SaveManager.get_all_slots():
		var info: Dictionary = SaveManager.get_save_info(slot)
		if slot != "autosave":
			button("Сохранить · " + slot.replace("slot_", "слот "), func() -> void: close(); SaveManager.save_game(slot))
		var entry: Button = button("%s · %s · %s" % [info.get("title", slot), info.get("location", ""), info.get("timestamp", "")], func() -> void: close(); SaveManager.load_game(slot))
		entry.disabled = not info.get("compatible", false)
	button("Назад", pause)

func settings() -> void:
	open("settings", "Звук и управление")
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 46)
	content.add_child(columns)
	var audio: VBoxContainer = VBoxContainer.new()
	audio.custom_minimum_size.x = 310
	audio.add_theme_constant_override("separation", 16)
	columns.add_child(audio)
	add_label(audio, "ЗВУК", 11, NoirUI.ACCENT)
	for entry: Array in [["Общая громкость", "master_volume", "set_master_volume"], ["Музыка", "music_volume", "set_music_volume"], ["Эффекты", "sfx_volume", "set_sfx_volume"]]:
		var label: Label = add_label(audio, "%s   %d%%" % [entry[0], roundi(SettingsManager.get(entry[1])*100)], 16)
		var slider: HSlider = HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size.y = 32
		slider.value = SettingsManager.get(entry[1])
		slider.value_changed.connect(func(value: float) -> void:
			SettingsManager.call(entry[2], value, true)
			label.text = "%s   %d%%" % [entry[0], roundi(value*100)]
		)
		audio.add_child(slider)
	add_label(audio, "Изменения сохраняются сразу.", 13, NoirUI.MUTED)
	var controls_column: VBoxContainer = VBoxContainer.new()
	controls_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_column.add_theme_constant_override("separation", 12)
	columns.add_child(controls_column)
	add_label(controls_column, "НАЗНАЧЕНИЕ КЛАВИШ", 11, NoirUI.ACCENT)
	add_label(controls_column, "Выберите клавишу для замены. Escape — отмена.", 13, NoirUI.MUTED)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 200 if root.size.y < 680 else 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_column.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item: Dictionary in SettingsManager.REBINDABLE_ACTIONS:
		if item.action == "toggle_history": continue
		var row: HBoxContainer = HBoxContainer.new()
		list.add_child(row)
		var title: String = "План квартиры" if item.action == "toggle_mind_palace" else str(item.name)
		if item.action == "toggle_clues": title = "Дневник"
		var name_label: Label = add_label(row, title, 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var assign: Button = Button.new()
		assign.text = key(item.action)
		assign.custom_minimum_size = Vector2(120,38)
		assign.add_theme_font_size_override("font_size", 15)
		assign.add_theme_stylebox_override("normal", NoirUI.keycap_style())
		assign.mouse_entered.connect(SoundManager.play_hover)
		assign.pressed.connect(SoundManager.play_click)
		assign.pressed.connect(func() -> void:
			rebind = item.action
			assign.text = "Нажмите…"
			assign.add_theme_color_override("font_color", NoirUI.ACCENT)
		)
		row.add_child(assign)
	button("Сбросить управление", func() -> void: SettingsManager.reset_keybinds_to_defaults(true); settings(), controls_column)
	button("Вернуться к игре", close)

func begin_qte() -> void:
	qte_progress = 0.0
	qte_time = 0.0
	qte_next = "move_left"
	qte_assist = false
	qte_paused = false
	open("qte", "Высвободиться", "Чередуйте показанные клавиши.")
	qte_label = add_label(content, "", 38, Color("f0d6b0"))
	qte_bar = ProgressBar.new()
	qte_bar.max_value = 10.0
	qte_bar.custom_minimum_size.y = 6
	qte_bar.show_percentage = false
	content.add_child(qte_bar)
	var actions: HBoxContainer = HBoxContainer.new()
	content.add_child(actions)
	button("Помощь · автоматически", func() -> void: qte_assist = true, actions)
	button("Пауза / продолжить", func() -> void: qte_paused = not qte_paused, actions)
	_update_qte_label()

func qte_press(action: String) -> void:
	if modal_kind != "qte" or qte_paused:
		return
	if action == qte_next:
		qte_progress += 1.0
		qte_next = "move_right" if qte_next == "move_left" else "move_left"
	else:
		qte_progress = maxf(0.0, qte_progress - 0.5)
	_update_qte_label()

func _update_qte_label() -> void:
	qte_label.text = "ПАУЗА" if qte_paused else "Нажмите " + key(qte_next)
	qte_bar.value = qte_progress

func key(action: String) -> String:
	return SettingsManager.get_action_key_name(action)

func _input(event: InputEvent) -> void:
	if host.intro_active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		host.skip_intro()
		get_viewport().set_input_as_handled()
		return
	if host.intro_active and not event.is_action_pressed("ui_cancel"):
		if event is InputEventMouse: return
		get_viewport().set_input_as_handled()
		return
	if modal_kind == "cabinet" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			host.story.enter_digit(int(event.keycode - KEY_0))
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			host.story.try_pin()
			get_viewport().set_input_as_handled()
			return
	if modal_kind == "message" and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		advance_message()
		return
	if not rebind.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode != KEY_ESCAPE:
				SettingsManager.rebind_action(rebind, event.physical_keycode if event.physical_keycode != 0 else event.keycode, true)
			rebind = ""
			settings()
		return
	if event is InputEventKey and event.keycode == KEY_TAB and not modal_kind.is_empty():
		return
	if modal_kind == "qte":
		var consumed: bool = false
		for action: String in ["move_left", "move_right"]:
			if event.is_action_pressed(action) and not event.is_echo():
				qte_press(action)
				consumed = true
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			qte_paused = not qte_paused
			_update_qte_label()
			consumed = true
		if consumed: get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if modal_kind in ["ending", "failure"]:
			return
		if modal_kind == "message":
			message_page = message_pages.size() - 1
			advance_message()
		elif modal.visible:
			close()
		else:
			pause()
	elif event.is_action_pressed("toggle_inventory") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if modal_kind == "inventory":
			close()
		elif modal_kind in ["", "journal", "map"]:
			inventory()
	elif event.is_action_pressed("toggle_clues") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if modal_kind == "journal":
			close()
		elif modal_kind in ["", "inventory", "map"]:
			journal()
	elif event.is_action_pressed("toggle_mind_palace") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if modal_kind == "map": close()
		elif modal_kind in ["", "inventory", "journal"]: apartment_map()
	elif event.is_action_pressed("toggle_history") and not event.is_echo() and modal_kind.is_empty():
		get_viewport().set_input_as_handled()
		help()

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(stress_bar):
		return
	# ScrollContainer minima settle after their child grid has been laid out.
	# Reclaim a transiently oversized PanelContainer after that deferred layout.
	if modal.visible and (modal.size.x > root.size.x - 48 or modal.size.y > root.size.y - 48):
		_layout_modal()
	stress_bar.value = ParanoiaManager.get_paranoia()
	stress_label.text = "ТРЕВОГА   %d" % roundi(stress_bar.value)
	stress_bar.modulate = Color("dc8d88") if stress_bar.value >= 80 else Color.WHITE
	var next_goal: String = host.current_goal()
	if next_goal != last_goal and not host.intro_active and modal_kind.is_empty() and host.state.has("opening_done"):
		last_goal = next_goal
		goal_notice_text.text = "Новая цель\n" + next_goal
		goal_notice_time = 4.5
	if modal_kind.is_empty() and not get_tree().paused:
		goal_notice_time = maxf(0.0, goal_notice_time - delta)
	goal_notice.visible = goal_notice_time > 0
	goal_notice.modulate.a = minf(1.0, goal_notice_time / 0.6)
	objective.text = next_goal
	goal_panel.visible = (host.state.has("opening_done") or host.state.has("dose")) and goal_notice_time <= 0
	inventory_button.text = key("toggle_inventory") + " · Сумка"
	journal_button.text = key("toggle_clues") + " · Дневник"
	tool_row.visible = host.state.phase == "encounter"
	for action: String in tool_buttons:
		var tool: Button = tool_buttons[action]
		var item: String = {"use_tool": "pepper", "throw_item": "throwable", "blind": "flashlight"}[action]
		tool.visible = InventoryManager.has_item(item)
		tool.text = key(action) + " · " + {"use_tool": "Перец", "throw_item": "Ваза", "blind": "Луч"}[action]
	_update_prompt()
	if not get_tree().paused and modal_kind.is_empty():
		toast_time -= delta
		if toast_time <= 0:
			toast.text = ""
			if not notification_queue.is_empty():
				var next: Dictionary = notification_queue.pop_front()
				notify(next.text, next.duration)
		toast_panel.visible = toast_time > 0
		toast_panel.modulate.a = clampf(toast_time / 0.35, 0, 1)
	if modal_kind == "qte" and not qte_paused:
		qte_time += delta
		if qte_assist:
			qte_progress += delta * 2.5
		_update_qte_label()
		if qte_progress >= 10.0:
			close()
			host.finish_coat()
		elif qte_time >= 18.0:
			open("qte_retry", "Это не конец", "Даша зацепилась за ткань. Попробуйте снова или включите помощь. Стресс и предметы не расходуются повторно.")
			button("Повторить", begin_qte)
			button("Повторить с помощью", func() -> void: begin_qte(); qte_assist = true)

func _update_prompt() -> void:
	prompt_panel.visible = not prompt.text.is_empty() and modal_kind.is_empty() and not host.intro_active
	if not prompt_panel.visible: return
	var point: Vector2 = host.player.global_position
	if host.selected == "enemy" and is_instance_valid(host.enemy): point = host.enemy.global_position
	elif host.world.interactables.has(host.selected): point = host.world.interactables[host.selected].global_position
	var screen: Vector2 = host.world.get_global_transform_with_canvas() * point
	prompt_panel.size = Vector2(clampf(prompt.get_theme_font("font").get_string_size(prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24, 180, 320), 40)
	var location: Vector2 = Vector2(clampf(screen.x + 20, 20, root.size.x - prompt_panel.size.x - 20), clampf(screen.y - 45, 110, root.size.y - 132))
	var player_screen: Vector2 = host.world.get_global_transform_with_canvas() * host.player.global_position
	var actor_rect: Rect2 = Rect2(player_screen - Vector2(28, 148), Vector2(56, 156))
	if Rect2(location, prompt_panel.size).intersects(actor_rect):
		location.x = player_screen.x + 34
		if location.x + prompt_panel.size.x > root.size.x - 20: location.x = player_screen.x - 314
	prompt_panel.position = location
