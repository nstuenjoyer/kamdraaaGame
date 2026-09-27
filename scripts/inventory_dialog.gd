extends CanvasLayer

# InventoryDialog — Окно инвентаря и вещевых доказательств Даши
# Открывается клавишей [ I ] во время игры или через меню паузы

@onready var backdrop: ColorRect = $Backdrop
@onready var window_panel: PanelContainer = $WindowPanel
@onready var item_list_container: VBoxContainer = $WindowPanel/Margin/VBox/ContentHBox/LeftCol/Scroll/ItemListContainer
@onready var empty_label: Label = $WindowPanel/Margin/VBox/ContentHBox/LeftCol/EmptyLabel
@onready var btn_close: Button = $WindowPanel/Margin/VBox/HeaderHBox/BtnClose
@onready var detail_panel: PanelContainer = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel
@onready var detail_icon: Label = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel/Margin/VBox/DetailIcon
@onready var detail_title: Label = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel/Margin/VBox/DetailTitle
@onready var detail_count: Label = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel/Margin/VBox/DetailCount
@onready var detail_desc: RichTextLabel = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel/Margin/VBox/DetailDesc
@onready var btn_use: Button = $WindowPanel/Margin/VBox/ContentHBox/RightCol/DetailPanel/Margin/VBox/BtnUse

var is_open: bool = false
var selected_item_id: String = ""

func _ready() -> void:
	visible = false
	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn_close:
		btn_close.pressed.connect(close_inventory)
	if btn_use:
		btn_use.pressed.connect(_on_use_pressed)

	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_signal("inventory_updated"):
		inv_mgr.inventory_updated.connect(_refresh_ui)

func _unhandled_input(event: InputEvent) -> void:
	# Открытие / закрытие по клавише I
	var is_key_i: bool = (event is InputEventKey and event.keycode == KEY_I and event.pressed and not event.is_echo())
	if is_key_i:
		get_viewport().set_input_as_handled()
		toggle_inventory()
		return

	if is_open:
		var is_esc: bool = (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo())
		if is_esc:
			get_viewport().set_input_as_handled()
			close_inventory()

func toggle_inventory() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	is_open = true
	visible = true
	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_interact"):
		sound_mgr.play_interact()

	# Блокируем движение игрока
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var player: Node = tree.current_scene.find_child("Player", true, false)
		if player and player.has_method("set_control_locked"):
			player.set_control_locked(true)

	_refresh_ui()

func close_inventory() -> void:
	is_open = false
	visible = false
	if backdrop:
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()

	# Разблокируем движение игрока, если не активен диалог
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var dialogue: Node = tree.current_scene.find_child("UI", true, false)
		var is_dialogue_active: bool = (dialogue and "is_active" in dialogue and dialogue.is_active)
		if not is_dialogue_active:
			var player: Node = tree.current_scene.find_child("Player", true, false)
			if player and player.has_method("set_control_locked"):
				player.set_control_locked(false)

func _refresh_ui() -> void:
	if not item_list_container:
		return

	# Очищаем старые кнопки
	for child in item_list_container.get_children():
		child.queue_free()

	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	var items: Array[Dictionary] = inv_mgr.get_all_items() if inv_mgr else []

	if items.is_empty():
		if empty_label:
			empty_label.visible = true
		if detail_panel:
			detail_panel.visible = false
		selected_item_id = ""
		return

	if empty_label:
		empty_label.visible = false
	if detail_panel:
		detail_panel.visible = true

	# Создаем карточки предметов
	var still_has_selected: bool = false
	for item_data in items:
		var item_id: String = item_data.get("id", "")
		var item_name: String = item_data.get("name", "")
		var count: int = item_data.get("count", 1)
		var icon_str: String = item_data.get("icon", "📦")
		var is_usable: bool = item_data.get("usable", false)

		if item_id == selected_item_id:
			still_has_selected = true

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "  %s  %s  (x%d)%s" % [icon_str, item_name, count, "  •  [Применимо]" if is_usable else ""]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var style_norm: StyleBoxFlat = StyleBoxFlat.new()
		style_norm.bg_color = Color(0.08, 0.12, 0.18, 0.85)
		style_norm.border_width_left = 2 if item_id == selected_item_id else 1
		style_norm.border_width_top = 1
		style_norm.border_width_right = 1
		style_norm.border_width_bottom = 1
		style_norm.border_color = Color(0.2, 0.85, 1.0, 0.95) if item_id == selected_item_id else Color(0.2, 0.32, 0.45, 0.6)
		style_norm.corner_radius_top_left = 4
		style_norm.corner_radius_top_right = 4
		style_norm.corner_radius_bottom_right = 4
		style_norm.corner_radius_bottom_left = 4
		btn.add_theme_stylebox_override("normal", style_norm)

		var style_hover: StyleBoxFlat = style_norm.duplicate()
		style_hover.bg_color = Color(0.14, 0.22, 0.32, 0.95)
		style_hover.border_color = Color(0.4, 0.9, 1.0, 1.0)
		btn.add_theme_stylebox_override("hover", style_hover)

		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		btn.mouse_entered.connect(func():
			if sound_mgr and sound_mgr.has_method("play_hover"):
				sound_mgr.play_hover()
		)
		btn.pressed.connect(func():
			_select_item(item_id)
		)

		item_list_container.add_child(btn)

	if not still_has_selected and not items.is_empty():
		_select_item(items[0].get("id", ""))
	elif still_has_selected:
		_select_item(selected_item_id)

func _select_item(id: String) -> void:
	selected_item_id = id
	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	var item_data: Dictionary = inv_mgr.get_item(id) if inv_mgr else {}

	if item_data.is_empty():
		if detail_panel:
			detail_panel.visible = false
		return

	if detail_panel:
		detail_panel.visible = true

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_click"):
		sound_mgr.play_click()

	if detail_icon:
		detail_icon.text = item_data.get("icon", "📦")
	if detail_title:
		detail_title.text = item_data.get("name", "Предмет")
	if detail_count:
		detail_count.text = "В наличии: %d шт." % item_data.get("count", 1)
	if detail_desc:
		detail_desc.text = item_data.get("description", "Обычный предмет из берлоги Даши.")

	if btn_use:
		var usable: bool = item_data.get("usable", false)
		btn_use.visible = usable
		if usable:
			btn_use.text = "Принять / Использовать"

func _on_use_pressed() -> void:
	if selected_item_id.is_empty():
		return

	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		inv_mgr.use_item(selected_item_id)
