extends CanvasLayer

# Скрипт меню паузы во время игры (PauseMenu)
# Позволяет сохранять игру в слоты, загружать сохранения, менять настройки и возвращаться в главное меню

@onready var container: Control = $PauseContainer
@onready var modal_backdrop: ColorRect = $PauseContainer/Backdrop
@onready var menu_panel: PanelContainer = $PauseContainer/MenuPanel

# Кнопки главного меню паузы
@onready var btn_resume: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnResume
@onready var btn_save: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnSave
@onready var btn_load: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnLoad
@onready var btn_settings: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnSettings
@onready var btn_main_menu: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnMainMenu

# Модальные окна
@onready var save_dialog: PanelContainer = $PauseContainer/SaveDialog
@onready var save_slot_container: VBoxContainer = $PauseContainer/SaveDialog/Margin/VBox/Scroll/SaveSlotContainer
@onready var btn_close_save: Button = $PauseContainer/SaveDialog/Margin/VBox/BtnCloseSave

@onready var load_dialog: PanelContainer = $PauseContainer/LoadDialog
@onready var load_slot_container: VBoxContainer = $PauseContainer/LoadDialog/Margin/VBox/Scroll/LoadSlotContainer
@onready var btn_close_load: Button = $PauseContainer/LoadDialog/Margin/VBox/BtnCloseLoad

@onready var settings_dialog: PanelContainer = $PauseContainer/SettingsDialog
@onready var slider_master: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/Grid/MasterSlider
@onready var lbl_master_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/Grid/MasterValue
@onready var slider_music: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/Grid/MusicSlider
@onready var lbl_music_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/Grid/MusicValue
@onready var slider_sfx: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/Grid/SFXSlider
@onready var lbl_sfx_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/Grid/SFXValue
@onready var check_fullscreen: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/OptionsList/CheckFullscreen
@onready var check_vsync: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/OptionsList/CheckVSync
@onready var check_crt: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/OptionsList/CheckCRT
@onready var btn_close_settings: Button = $PauseContainer/SettingsDialog/Margin/VBox/BtnCloseSettings

# Toast уведомления
@onready var toast_panel: PanelContainer = $PauseContainer/ToastNotification
@onready var toast_label: Label = $PauseContainer/ToastNotification/Margin/ToastLabel

var toast_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	container.visible = false
	_close_all_modals()

	_connect_buttons()
	_connect_settings()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.connect(show_toast)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo()):
		# Проверяем, не открыт ли диалог UI игры
		var ui_dialogue: CanvasLayer = get_node_or_null("../UI") as CanvasLayer
		if ui_dialogue and "is_active" in ui_dialogue and ui_dialogue.is_active:
			return # Не перехватываем ESC во время диалога

		get_viewport().set_input_as_handled()
		if save_dialog.visible or load_dialog.visible or settings_dialog.visible:
			_close_all_modals()
		else:
			toggle_pause()

	elif event is InputEventKey and event.keycode == KEY_F5 and event.pressed and not event.is_echo():
		# Быстрое сохранение (F5)
		get_viewport().set_input_as_handled()
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.save_game("slot_1", "Быстрое сохранение [F5]")

	elif event is InputEventKey and event.keycode == KEY_F9 and event.pressed and not event.is_echo():
		# Быстрая загрузка (F9)
		get_viewport().set_input_as_handled()
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.save_exists("slot_1"):
			save_mgr.load_game("slot_1")

func toggle_pause() -> void:
	var new_paused: bool = not get_tree().paused
	get_tree().paused = new_paused
	container.visible = new_paused
	
	if new_paused:
		_close_all_modals()
		menu_panel.visible = true
		btn_resume.grab_focus()
	else:
		_close_all_modals()

func _connect_buttons() -> void:
	btn_resume.pressed.connect(func(): toggle_pause())
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)

	btn_close_save.pressed.connect(_close_all_modals)
	btn_close_load.pressed.connect(_close_all_modals)
	btn_close_settings.pressed.connect(_close_all_modals)

	_bind_sound_feedback([btn_resume, btn_save, btn_load, btn_settings, btn_main_menu, btn_close_save, btn_close_load, btn_close_settings])

func _bind_sound_feedback(buttons: Array[Button]) -> void:
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	for btn in buttons:
		if not btn:
			continue
		btn.mouse_entered.connect(func():
			if sound_mgr and sound_mgr.has_method("play_hover"):
				sound_mgr.play_hover()
		)
		btn.pressed.connect(func():
			if sound_mgr and sound_mgr.has_method("play_click"):
				sound_mgr.play_click()
		)

func _on_save_pressed() -> void:
	_populate_save_slots()
	menu_panel.visible = false
	save_dialog.visible = true

func _on_load_pressed() -> void:
	_populate_load_slots()
	menu_panel.visible = false
	load_dialog.visible = true

func _on_settings_pressed() -> void:
	_sync_settings_ui()
	menu_panel.visible = false
	settings_dialog.visible = true

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _close_all_modals() -> void:
	save_dialog.visible = false
	load_dialog.visible = false
	settings_dialog.visible = false
	menu_panel.visible = true

func _populate_save_slots() -> void:
	for child in save_slot_container.get_children():
		child.queue_free()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	# Для ручного сохранения предлагаем Слот 1, 2, 3
	for slot_id in ["slot_1", "slot_2", "slot_3"]:
		var info: Dictionary = save_mgr.get_save_info(slot_id)
		var card: PanelContainer = _create_slot_card(slot_id, info, true)
		save_slot_container.add_child(card)

func _populate_load_slots() -> void:
	for child in load_slot_container.get_children():
		child.queue_free()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	for slot_id in save_mgr.get_all_slots():
		var info: Dictionary = save_mgr.get_save_info(slot_id)
		var card: PanelContainer = _create_slot_card(slot_id, info, false)
		load_slot_container.add_child(card)

func _create_slot_card(slot_id: String, info: Dictionary, is_save_mode: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var exists: bool = info.get("exists", false)

	style.bg_color = Color(0.12, 0.15, 0.22, 0.9) if exists else Color(0.08, 0.1, 0.14, 0.7)
	style.border_color = Color(0.2, 0.6, 0.8, 0.8) if exists else Color(0.2, 0.25, 0.35, 0.4)
	style.border_width_left = 3
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	card.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.theme_override_constants.set("separation", 12)
	margin.add_child(hbox)

	var vbox_info: VBoxContainer = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_info)

	var title_lbl: Label = Label.new()
	title_lbl.text = info.get("title", slot_id)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.modulate = Color(0.4, 0.85, 1.0)
	vbox_info.add_child(title_lbl)

	var meta_lbl: Label = Label.new()
	if exists:
		meta_lbl.text = "🕒 %s  •  📍 %s\n%s" % [info.get("timestamp", ""), info.get("location", ""), info.get("details", "")]
		meta_lbl.modulate = Color(0.75, 0.8, 0.9, 0.9)
	else:
		meta_lbl.text = "Пустая ячейка"
		meta_lbl.modulate = Color(0.5, 0.55, 0.65, 0.6)
	meta_lbl.add_theme_font_size_override("font_size", 11)
	vbox_info.add_child(meta_lbl)

	var actions_box: HBoxContainer = HBoxContainer.new()
	hbox.add_child(actions_box)

	if is_save_mode:
		var btn_action: Button = Button.new()
		btn_action.text = "Перезаписать" if exists else "Сохранить"
		btn_action.custom_minimum_size = Vector2(110, 34)
		btn_action.pressed.connect(func():
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			if save_mgr:
				save_mgr.save_game(slot_id)
				_populate_save_slots()
		)
		actions_box.add_child(btn_action)
	else:
		if exists:
			var btn_action: Button = Button.new()
			btn_action.text = "Загрузить"
			btn_action.custom_minimum_size = Vector2(95, 34)
			btn_action.pressed.connect(func():
				var save_mgr: Node = get_node_or_null("/root/SaveManager")
				if save_mgr:
					save_mgr.load_game(slot_id)
					toggle_pause()
			)
			actions_box.add_child(btn_action)
		else:
			var lbl_empty: Label = Label.new()
			lbl_empty.text = "—"
			actions_box.add_child(lbl_empty)

	return card

func _connect_settings() -> void:
	slider_master.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_master_volume(val / 100.0)
		lbl_master_val.text = "%d%%" % int(val)
	)
	slider_music.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_music_volume(val / 100.0)
		lbl_music_val.text = "%d%%" % int(val)
	)
	slider_sfx.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_sfx_volume(val / 100.0)
		lbl_sfx_val.text = "%d%%" % int(val)
	)
	check_fullscreen.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_fullscreen(enabled)
	)
	check_vsync.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_vsync(enabled)
	)
	check_crt.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_crt_effect(enabled)
	)

func _sync_settings_ui() -> void:
	var mgr: Node = get_node_or_null("/root/SettingsManager")
	if not mgr:
		return
	slider_master.value = mgr.master_volume * 100.0
	lbl_master_val.text = "%d%%" % int(slider_master.value)
	slider_music.value = mgr.music_volume * 100.0
	lbl_music_val.text = "%d%%" % int(slider_music.value)
	slider_sfx.value = mgr.sfx_volume * 100.0
	lbl_sfx_val.text = "%d%%" % int(slider_sfx.value)
	check_fullscreen.button_pressed = mgr.fullscreen
	check_vsync.button_pressed = mgr.vsync
	check_crt.button_pressed = mgr.crt_effect

func show_toast(text: String) -> void:
	if not toast_panel or not toast_label:
		return
	toast_label.text = text
	toast_panel.visible = true

	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	toast_tween = create_tween()
	toast_panel.modulate.a = 0.0
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	toast_tween.finished.connect(func(): toast_panel.visible = false)
