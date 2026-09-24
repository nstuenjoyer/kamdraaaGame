extends Control

# Скрипт главного меню (MainMenu)
# Отвечает за навигацию, диалоги сохранения/загрузки, настройки и экран "Об игре"

const GAME_SCENE_PATH: String = "res://scenes/main.tscn"

# Главные кнопки
@onready var btn_play: Button = $Content/MenuButtons/BtnPlay
@onready var btn_load: Button = $Content/MenuButtons/BtnLoad
@onready var btn_settings: Button = $Content/MenuButtons/BtnSettings
@onready var btn_quit: Button = $Content/MenuButtons/BtnQuit
@onready var btn_about: Button = $Content/MenuButtons/BtnAbout

# Панели
@onready var modal_backdrop: ColorRect = $ModalBackdrop
@onready var play_dialog: PanelContainer = $Modals/PlayDialog
@onready var load_dialog: PanelContainer = $Modals/LoadDialog
@onready var settings_dialog: PanelContainer = $Modals/SettingsDialog
@onready var about_dialog: PanelContainer = $Modals/AboutDialog

# Элементы диалога игры (Продолжить / Новая игра)
@onready var btn_continue: Button = $Modals/PlayDialog/Margin/VBox/BtnContinue
@onready var btn_new_game: Button = $Modals/PlayDialog/Margin/VBox/BtnNewGame
@onready var btn_cancel_play: Button = $Modals/PlayDialog/Margin/VBox/BtnCancelPlay

# Элементы диалога загрузки
@onready var slot_container: VBoxContainer = $Modals/LoadDialog/Margin/VBox/Scroll/SlotContainer
@onready var btn_close_load: Button = $Modals/LoadDialog/Margin/VBox/LoadFooter/BtnCloseLoad
@onready var btn_restore_saves: Button = $Modals/LoadDialog/Margin/VBox/LoadFooter/BtnRestoreSaves

# Элементы диалога настроек
@onready var slider_master: HSlider = $Modals/SettingsDialog/Margin/VBox/Grid/MasterSlider
@onready var lbl_master_val: Label = $Modals/SettingsDialog/Margin/VBox/Grid/MasterValue
@onready var slider_music: HSlider = $Modals/SettingsDialog/Margin/VBox/Grid/MusicSlider
@onready var lbl_music_val: Label = $Modals/SettingsDialog/Margin/VBox/Grid/MusicValue
@onready var slider_sfx: HSlider = $Modals/SettingsDialog/Margin/VBox/Grid/SFXSlider
@onready var lbl_sfx_val: Label = $Modals/SettingsDialog/Margin/VBox/Grid/SFXValue
@onready var check_fullscreen: CheckBox = $Modals/SettingsDialog/Margin/VBox/OptionsList/CheckFullscreen
@onready var check_vsync: CheckBox = $Modals/SettingsDialog/Margin/VBox/OptionsList/CheckVSync
@onready var check_crt: CheckBox = $Modals/SettingsDialog/Margin/VBox/OptionsList/CheckCRT
@onready var btn_close_settings: Button = $Modals/SettingsDialog/Margin/VBox/BtnCloseSettings

# Элементы диалога "Об игре"
@onready var btn_close_about: Button = $Modals/AboutDialog/Margin/VBox/BtnCloseAbout

# Уведомления (Toast)
@onready var toast_panel: PanelContainer = $ToastNotification
@onready var toast_label: Label = $ToastNotification/Margin/ToastLabel

# Анимация заголовка
@onready var title_label: Label = $Content/Header/Title

var toast_tween: Tween

func _ready() -> void:
	_connect_main_buttons()
	_connect_modal_buttons()
	_connect_settings_controls()
	_init_title_neon_pulse()
	_close_all_modals(true)
	
	if toast_panel:
		toast_panel.modulate.a = 0.0
		toast_panel.visible = false

	# Подписка на глобальные сигналы сохранений
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		if save_mgr.has_signal("toast_requested"):
			save_mgr.toast_requested.connect(show_toast)
		if save_mgr.has_signal("save_deleted"):
			save_mgr.save_deleted.connect(func(_slot_id): _populate_load_slots())

	# Подсветка доступности кнопки "Загрузить"
	_update_load_button_state()
	btn_play.grab_focus()

func _update_load_button_state() -> void:
	if btn_load:
		btn_load.text = "💾  ЗАГРУЗИТЬ"
		btn_load.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _init_title_neon_pulse() -> void:
	if not title_label:
		return
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(1.2, 1.0, 1.3, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "modulate", Color(0.85, 0.95, 1.15, 1.0), 1.8).set_trans(Tween.TRANS_SINE)

func _connect_main_buttons() -> void:
	btn_play.pressed.connect(_on_play_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_about.pressed.connect(_on_about_pressed)

	_bind_sound_feedback([btn_play, btn_load, btn_settings, btn_quit, btn_about])

func _connect_modal_buttons() -> void:
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_cancel_play.pressed.connect(func(): _close_all_modals())
	btn_close_load.pressed.connect(func(): _close_all_modals())
	if btn_restore_saves:
		btn_restore_saves.pressed.connect(func():
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			if save_mgr and save_mgr.has_method("create_sample_saves"):
				save_mgr.create_sample_saves()
				_populate_load_slots()
				_update_load_button_state()
				show_toast("💾 Демо-сохранения восстановлены")
		)
	btn_close_settings.pressed.connect(func(): _close_all_modals())
	btn_close_about.pressed.connect(func(): _close_all_modals())

	var modal_btns: Array[Button] = [btn_continue, btn_new_game, btn_cancel_play, btn_close_load, btn_close_settings, btn_close_about]
	if btn_restore_saves:
		modal_btns.append(btn_restore_saves)
	_bind_sound_feedback(modal_btns)

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

func _on_play_pressed() -> void:
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_any_save():
		_open_modal(play_dialog)
	else:
		_start_fresh_game()

func _on_continue_pressed() -> void:
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		var latest_slot: String = save_mgr.get_latest_save_slot()
		if not latest_slot.is_empty():
			save_mgr.load_game(latest_slot)
			return
	_start_fresh_game()

func _on_new_game_pressed() -> void:
	_start_fresh_game()

func _start_fresh_game() -> void:
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.pending_save_data = {}
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_load_pressed() -> void:
	_populate_load_slots()
	_open_modal(load_dialog)

func _populate_load_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	var slots: Array[String] = save_mgr.get_all_slots()
	for slot_id in slots:
		var info: Dictionary = save_mgr.get_save_info(slot_id)
		var card: PanelContainer = _create_slot_card(slot_id, info)
		slot_container.add_child(card)

func _create_slot_card(slot_id: String, info: Dictionary) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var exists: bool = info.get("exists", false)
	
	style.bg_color = Color(0.12, 0.15, 0.22, 0.85) if exists else Color(0.08, 0.1, 0.14, 0.6)
	style.border_color = Color(0.2, 0.6, 0.8, 0.8) if exists else Color(0.2, 0.25, 0.35, 0.4)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	card.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.theme_override_constants.set("separation", 16)
	margin.add_child(hbox)

	# Иконка / Статус
	var icon_label: Label = Label.new()
	icon_label.text = "💾" if exists else "📁"
	icon_label.add_theme_font_size_override("font_size", 22)
	hbox.add_child(icon_label)

	# Текстовая информация
	var vbox_info: VBoxContainer = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_info)

	var title_lbl: Label = Label.new()
	title_lbl.text = info.get("title", slot_id)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.modulate = Color(1.0, 0.9, 0.5) if slot_id == "autosave" else Color(0.4, 0.85, 1.0)
	vbox_info.add_child(title_lbl)

	var meta_lbl: Label = Label.new()
	if exists:
		var loc: String = info.get("location", "Конспиративная берлога")
		var time_str: String = info.get("timestamp", "")
		var details: String = info.get("details", "")
		meta_lbl.text = "📍 %s  •  🕒 %s\n%s" % [loc, time_str, details]
		meta_lbl.modulate = Color(0.75, 0.8, 0.9, 0.9)
	else:
		meta_lbl.text = "Пустая ячейка для сохранения"
		meta_lbl.modulate = Color(0.5, 0.55, 0.65, 0.6)
	meta_lbl.add_theme_font_size_override("font_size", 11)
	vbox_info.add_child(meta_lbl)

	# Кнопки действий
	var vbox_actions: HBoxContainer = HBoxContainer.new()
	vbox_actions.theme_override_constants.set("separation", 8)
	hbox.add_child(vbox_actions)

	if exists:
		var btn_load_slot: Button = Button.new()
		btn_load_slot.text = "Загрузить"
		btn_load_slot.custom_minimum_size = Vector2(95, 36)
		btn_load_slot.pressed.connect(func():
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			if save_mgr:
				save_mgr.load_game(slot_id)
		)
		vbox_actions.add_child(btn_load_slot)

		var btn_del_slot: Button = Button.new()
		btn_del_slot.text = "✖"
		btn_del_slot.custom_minimum_size = Vector2(36, 36)
		btn_del_slot.tooltip_text = "Удалить сохранение"
		btn_del_slot.pressed.connect(func():
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			if save_mgr:
				save_mgr.delete_save(slot_id)
				_update_load_button_state()
		)
		vbox_actions.add_child(btn_del_slot)
	else:
		var btn_quick_save: Button = Button.new()
		btn_quick_save.text = "+ Сейв"
		btn_quick_save.custom_minimum_size = Vector2(95, 36)
		btn_quick_save.tooltip_text = "Создать контрольную точку в этой ячейке"
		btn_quick_save.pressed.connect(func():
			var save_mgr: Node = get_node_or_null("/root/SaveManager")
			if save_mgr and save_mgr.has_method("create_sample_save_for_slot"):
				save_mgr.create_sample_save_for_slot(slot_id)
				_populate_load_slots()
				_update_load_button_state()
				show_toast("💾 Создано сохранение: " + info.get("title", slot_id))
		)
		vbox_actions.add_child(btn_quick_save)

	return card

func _on_settings_pressed() -> void:
	_sync_settings_ui()
	_open_modal(settings_dialog)

func _connect_settings_controls() -> void:
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

func _on_about_pressed() -> void:
	_open_modal(about_dialog)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _open_modal(target_dialog: Control) -> void:
	_close_all_modals(true)
	modal_backdrop.visible = true
	target_dialog.visible = true
	target_dialog.scale = Vector2(0.92, 0.92)
	target_dialog.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(modal_backdrop, "modulate:a", 1.0, 0.2)
	tween.tween_property(target_dialog, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_dialog, "modulate:a", 1.0, 0.2)

func _close_all_modals(instant: bool = false) -> void:
	if instant:
		modal_backdrop.visible = false
		modal_backdrop.modulate.a = 0.0
		play_dialog.visible = false
		load_dialog.visible = false
		settings_dialog.visible = false
		about_dialog.visible = false
		return

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(modal_backdrop, "modulate:a", 0.0, 0.15)
	for d in [play_dialog, load_dialog, settings_dialog, about_dialog]:
		if d.visible:
			tween.tween_property(d, "modulate:a", 0.0, 0.15)
			tween.tween_property(d, "scale", Vector2(0.95, 0.95), 0.15)
	tween.finished.connect(func():
		modal_backdrop.visible = false
		play_dialog.visible = false
		load_dialog.visible = false
		settings_dialog.visible = false
		about_dialog.visible = false
		if btn_play and is_inside_tree():
			btn_play.grab_focus()
	)

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
	toast_tween.tween_interval(2.5)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	toast_tween.finished.connect(func(): toast_panel.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal_backdrop.visible:
			_close_all_modals()
			get_viewport().set_input_as_handled()
