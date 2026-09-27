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
@onready var tab_header: HBoxContainer = $Modals/SettingsDialog/Margin/VBox/TabHeader
@onready var btn_tab_audio: Button = $Modals/SettingsDialog/Margin/VBox/TabHeader/BtnTabAudio
@onready var btn_tab_text: Button = $Modals/SettingsDialog/Margin/VBox/TabHeader/BtnTabText
@onready var btn_tab_controls: Button = $Modals/SettingsDialog/Margin/VBox/TabHeader/BtnTabControls
@onready var audio_tab: VBoxContainer = $Modals/SettingsDialog/Margin/VBox/AudioTab
@onready var text_tab: VBoxContainer = $Modals/SettingsDialog/Margin/VBox/TextTab
@onready var controls_tab: VBoxContainer = $Modals/SettingsDialog/Margin/VBox/ControlsTab

@onready var slider_text_speed: HSlider = $Modals/SettingsDialog/Margin/VBox/TextTab/Grid/SpeedSlider
@onready var lbl_text_speed_val: Label = $Modals/SettingsDialog/Margin/VBox/TextTab/Grid/SpeedValue
@onready var slider_advance_delay: HSlider = $Modals/SettingsDialog/Margin/VBox/TextTab/Grid/DelaySlider
@onready var lbl_advance_delay_val: Label = $Modals/SettingsDialog/Margin/VBox/TextTab/Grid/DelayValue
@onready var check_auto_advance: CheckBox = $Modals/SettingsDialog/Margin/VBox/TextTab/OptionsList/CheckAutoAdvance

@onready var slider_master: HSlider = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/MasterSlider
@onready var lbl_master_val: Label = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/MasterValue
@onready var slider_music: HSlider = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/MusicSlider
@onready var lbl_music_val: Label = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/MusicValue
@onready var slider_sfx: HSlider = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/SFXSlider
@onready var lbl_sfx_val: Label = $Modals/SettingsDialog/Margin/VBox/AudioTab/Grid/SFXValue
@onready var check_fullscreen: CheckBox = $Modals/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckFullscreen
@onready var check_vsync: CheckBox = $Modals/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckVSync
@onready var check_crt: CheckBox = $Modals/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckCRT

@onready var keybind_list: VBoxContainer = $Modals/SettingsDialog/Margin/VBox/ControlsTab/ScrollControls/KeybindList
@onready var btn_reset_keybinds: Button = $Modals/SettingsDialog/Margin/VBox/ControlsTab/BtnResetKeybinds
@onready var btn_apply_settings: Button = $Modals/SettingsDialog/Margin/VBox/SettingsFooter/BtnApplySettings
@onready var btn_close_settings: Button = $Modals/SettingsDialog/Margin/VBox/SettingsFooter/BtnCloseSettings

# Диалог подтверждения несохраненных настроек
@onready var settings_confirm_dialog: PanelContainer = $Modals/SettingsConfirmDialog
@onready var btn_confirm_save: Button = $Modals/SettingsConfirmDialog/Margin/VBox/HBox/BtnConfirmSave
@onready var btn_discard_save: Button = $Modals/SettingsConfirmDialog/Margin/VBox/HBox/BtnDiscardSave
@onready var btn_cancel_confirm: Button = $Modals/SettingsConfirmDialog/Margin/VBox/HBox/BtnCancelConfirm

# Элементы диалога "Об игре"
@onready var btn_close_about: Button = $Modals/AboutDialog/Margin/VBox/BtnCloseAbout

# Уведомления (Toast)
@onready var toast_panel: PanelContainer = $ToastNotification
@onready var toast_label: Label = $ToastNotification/Margin/ToastLabel

# Анимация заголовка и неоновое мерцание
@onready var title_label: Label = $Content/Header/Title
@onready var rain_overlay: ColorRect = get_node_or_null("RainOverlay") as ColorRect

var toast_tween: Tween
var _has_unsaved_settings: bool = false
var _is_syncing_settings: bool = false

var _neon_timer: float = 0.0
var _neon_flicker_duration: float = 0.0
var _neon_flicker_factor: float = 1.0

func _ready() -> void:
	_connect_main_buttons()
	_connect_modal_buttons()
	_connect_settings_controls()
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

	_update_load_button_state()
	btn_play.grab_focus()

func _update_load_button_state() -> void:
	if btn_load:
		btn_load.text = "💾  ЗАГРУЗИТЬ"
		btn_load.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	_neon_timer += delta
	var t: float = _neon_timer

	# Плавная базовая синусоидальная пульсация неонового свечения
	var pulse: float = 0.92 + 0.16 * sin(t * 1.7)

	# Спонтанные микро-сбои и перебои напряжения неоновой трубки
	if _neon_flicker_duration > 0.0:
		_neon_flicker_duration -= delta
		_neon_flicker_factor = randf_range(0.38, 1.25)
	else:
		_neon_flicker_factor = 1.0
		# Случайный запуск короткого сбоя неоновой лампы
		if randf() < 0.012:
			_neon_flicker_duration = randf_range(0.06, 0.18)

	var total_intensity: float = pulse * _neon_flicker_factor

	# Гармонизация мерцания заголовка Kamdraaa и шейдера дождя за окном
	if title_label:
		var c_neon: Color = Color(1.05 * total_intensity, 0.94 * total_intensity, 1.2 * total_intensity, 1.0)
		title_label.modulate = c_neon

	if rain_overlay and rain_overlay.material is ShaderMaterial:
		(rain_overlay.material as ShaderMaterial).set_shader_parameter("neon_flicker", total_intensity)
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
	btn_close_settings.pressed.connect(_on_try_close_settings)
	btn_apply_settings.pressed.connect(_on_apply_settings_pressed)
	btn_close_about.pressed.connect(func(): _close_all_modals())

	btn_confirm_save.pressed.connect(_on_confirm_save_pressed)
	btn_discard_save.pressed.connect(_on_discard_save_pressed)
	btn_cancel_confirm.pressed.connect(_on_cancel_confirm_pressed)

	var modal_btns: Array[Button] = [
		btn_continue, btn_new_game, btn_cancel_play, btn_close_load,
		btn_apply_settings, btn_close_settings, btn_close_about,
		btn_tab_audio, btn_tab_controls, btn_reset_keybinds,
		btn_confirm_save, btn_discard_save, btn_cancel_confirm
	]
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
	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	if paranoia_mgr and paranoia_mgr.has_method("reset_to_default"):
		paranoia_mgr.reset_to_default()
	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("reset_inventory"):
		inv_mgr.reset_inventory()
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
	hbox.add_theme_constant_override("separation", 16)
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
	vbox_actions.add_theme_constant_override("separation", 8)
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

var _rebinding_action: String = ""
var _rebinding_button: Button = null

func _on_settings_pressed() -> void:
	_switch_settings_tab("audio")
	_is_syncing_settings = true
	_sync_settings_ui()
	_is_syncing_settings = false
	_has_unsaved_settings = false
	_update_save_button_state()
	_open_modal(settings_dialog)

func _mark_settings_dirty() -> void:
	if _is_syncing_settings:
		return
	_has_unsaved_settings = true
	_update_save_button_state()

func _update_save_button_state() -> void:
	if not btn_apply_settings:
		return
	if _has_unsaved_settings:
		btn_apply_settings.text = "💾 Сохранить изменения *"
		btn_apply_settings.modulate = Color(1.3, 1.2, 0.4, 1.0)
	else:
		btn_apply_settings.text = "✔ Сохранить настройки"
		btn_apply_settings.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_apply_settings_pressed() -> void:
	var mgr: Node = get_node_or_null("/root/SettingsManager")
	if mgr:
		mgr.save_settings()
	_has_unsaved_settings = false
	_update_save_button_state()
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_interact"):
		sound_mgr.play_interact()
	show_toast("✔ Настройки сохранены")

func _on_try_close_settings() -> void:
	if _has_unsaved_settings:
		_open_settings_confirm_dialog()
	else:
		_close_all_modals()

func _open_settings_confirm_dialog() -> void:
	if not settings_confirm_dialog:
		_close_all_modals()
		return
	settings_confirm_dialog.visible = true
	settings_confirm_dialog.scale = Vector2(0.92, 0.92)
	settings_confirm_dialog.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(settings_confirm_dialog, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_confirm_dialog, "modulate:a", 1.0, 0.2)
	btn_confirm_save.grab_focus()

func _on_confirm_save_pressed() -> void:
	var mgr: Node = get_node_or_null("/root/SettingsManager")
	if mgr:
		mgr.save_settings()
	_has_unsaved_settings = false
	_update_save_button_state()
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_click"):
		sound_mgr.play_click()
	show_toast("✔ Настройки сохранены")
	_close_all_modals()

func _on_discard_save_pressed() -> void:
	var mgr: Node = get_node_or_null("/root/SettingsManager")
	if mgr:
		mgr.revert_settings()
	_has_unsaved_settings = false
	_update_save_button_state()
	_is_syncing_settings = true
	_sync_settings_ui()
	_is_syncing_settings = false
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()
	show_toast("↺ Изменения настроек сброшены")
	_close_all_modals()

func _on_cancel_confirm_pressed() -> void:
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()
	settings_confirm_dialog.visible = false
	if btn_close_settings:
		btn_close_settings.grab_focus()

func _switch_settings_tab(tab_name: String) -> void:
	_cancel_key_rebind()
	audio_tab.visible = (tab_name == "audio")
	text_tab.visible = (tab_name == "text")
	controls_tab.visible = (tab_name == "controls")

	btn_tab_audio.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "audio" else Color(0.65, 0.7, 0.8, 0.7)
	btn_tab_text.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "text" else Color(0.65, 0.7, 0.8, 0.7)
	btn_tab_controls.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "controls" else Color(0.65, 0.7, 0.8, 0.7)

	if tab_name == "controls":
		_populate_keybinds()

func _connect_settings_controls() -> void:
	btn_tab_audio.pressed.connect(func(): _switch_settings_tab("audio"))
	btn_tab_text.pressed.connect(func(): _switch_settings_tab("text"))
	btn_tab_controls.pressed.connect(func(): _switch_settings_tab("controls"))

	slider_text_speed.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.set_text_speed(int(val))
			lbl_text_speed_val.text = mgr.get_speed_title()
		_mark_settings_dirty()
	)
	slider_advance_delay.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.set_auto_advance_delay(val)
			lbl_advance_delay_val.text = "%.1f сек" % val
		_mark_settings_dirty()
	)
	check_auto_advance.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.set_auto_advance(enabled)
		_mark_settings_dirty()
	)

	slider_master.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_master_volume(val / 100.0)
		lbl_master_val.text = "%d%%" % int(val)
		_mark_settings_dirty()
	)
	slider_music.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_music_volume(val / 100.0)
		lbl_music_val.text = "%d%%" % int(val)
		_mark_settings_dirty()
	)
	slider_sfx.value_changed.connect(func(val: float):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_sfx_volume(val / 100.0)
		lbl_sfx_val.text = "%d%%" % int(val)
		_mark_settings_dirty()
	)
	check_fullscreen.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_fullscreen(enabled)
		_mark_settings_dirty()
	)
	check_vsync.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_vsync(enabled)
		_mark_settings_dirty()
	)
	check_crt.toggled.connect(func(enabled: bool):
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr: mgr.set_crt_effect(enabled)
		_mark_settings_dirty()
	)

	btn_reset_keybinds.pressed.connect(func():
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			mgr.reset_keybinds_to_defaults()
			_populate_keybinds()
			_mark_settings_dirty()
			show_toast("↺ Клавиши сброшены по умолчанию")
	)

func _populate_keybinds() -> void:
	for child in keybind_list.get_children():
		child.queue_free()

	var mgr: Node = get_node_or_null("/root/SettingsManager")
	if not mgr:
		return

	for item in mgr.REBINDABLE_ACTIONS:
		var act_name: String = item["action"]
		var act_title: String = item["name"]

		var row: PanelContainer = PanelContainer.new()
		var row_style: StyleBoxFlat = StyleBoxFlat.new()
		row_style.bg_color = Color(0.08, 0.1, 0.16, 0.75)
		row_style.corner_radius_top_left = 6
		row_style.corner_radius_top_right = 6
		row_style.corner_radius_bottom_right = 6
		row_style.corner_radius_bottom_left = 6
		row.add_theme_stylebox_override("panel", row_style)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		row.add_child(margin)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)

		var lbl: Label = Label.new()
		lbl.text = act_title
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl)

		var btn_bind: Button = Button.new()
		btn_bind.custom_minimum_size = Vector2(160, 32)
		btn_bind.text = "[ " + mgr.get_action_key_name(act_name) + " ]"
		btn_bind.add_theme_font_size_override("font_size", 13)

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.12, 0.18, 0.28, 0.9)
		btn_style.border_color = Color(0.3, 0.6, 0.8, 0.8)
		btn_style.set_border_width_all(1)
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_bind.add_theme_stylebox_override("normal", btn_style)

		btn_bind.pressed.connect(func():
			_start_key_rebind(act_name, btn_bind)
		)
		hbox.add_child(btn_bind)

		keybind_list.add_child(row)

func _start_key_rebind(action_name: String, btn: Button) -> void:
	if _rebinding_action != "":
		_cancel_key_rebind()
	_rebinding_action = action_name
	_rebinding_button = btn
	btn.text = "⌨ Нажмите клавишу..."
	btn.modulate = Color(1.3, 1.2, 0.4, 1.0)

func _cancel_key_rebind() -> void:
	if _rebinding_button and _rebinding_action != "":
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			_rebinding_button.text = "[ " + mgr.get_action_key_name(_rebinding_action) + " ]"
		_rebinding_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_rebinding_action = ""
	_rebinding_button = null

func _finish_key_rebind() -> void:
	if _rebinding_button and _rebinding_action != "":
		var mgr: Node = get_node_or_null("/root/SettingsManager")
		if mgr:
			_rebinding_button.text = "[ " + mgr.get_action_key_name(_rebinding_action) + " ]"
		_rebinding_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_rebinding_action = ""
	_rebinding_button = null

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
	slider_text_speed.value = float(mgr.text_speed_mode)
	lbl_text_speed_val.text = mgr.get_speed_title()
	check_auto_advance.button_pressed = mgr.auto_advance
	slider_advance_delay.value = mgr.auto_advance_delay
	lbl_advance_delay_val.text = "%.1f сек" % mgr.auto_advance_delay
	_populate_keybinds()

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
		if settings_confirm_dialog:
			settings_confirm_dialog.visible = false
		about_dialog.visible = false
		return

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(modal_backdrop, "modulate:a", 0.0, 0.15)
	for d in [play_dialog, load_dialog, settings_dialog, settings_confirm_dialog, about_dialog]:
		if d and d.visible:
			tween.tween_property(d, "modulate:a", 0.0, 0.15)
			tween.tween_property(d, "scale", Vector2(0.95, 0.95), 0.15)
	tween.finished.connect(func():
		modal_backdrop.visible = false
		play_dialog.visible = false
		load_dialog.visible = false
		settings_dialog.visible = false
		if settings_confirm_dialog:
			settings_confirm_dialog.visible = false
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
		
	toast_panel.modulate.a = 0.0
	toast_panel.offset_top = 10.0
	toast_panel.offset_bottom = 56.0

	toast_tween = create_tween()
	toast_tween.parallel().tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_tween.parallel().tween_property(toast_panel, "offset_top", 24.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	toast_tween.parallel().tween_property(toast_panel, "offset_bottom", 70.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	toast_tween.finished.connect(func():
		toast_panel.visible = false
		toast_panel.offset_top = 24.0
		toast_panel.offset_bottom = 70.0
	)

func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action != "":
		if event is InputEventKey and event.pressed and not event.is_echo():
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_cancel_key_rebind()
				show_toast("Отмена переназначения клавиши")
			else:
				var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
				var mgr: Node = get_node_or_null("/root/SettingsManager")
				if mgr:
					mgr.rebind_action(_rebinding_action, code)
					_mark_settings_dirty()
					show_toast("⌨ Клавиша назначена: " + OS.get_keycode_string(code))
				_finish_key_rebind()
			return

	var is_cancel_key: bool = event.is_action_pressed("ui_cancel") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_ESCAPE or event.keycode == KEY_P
		)
	)
	var is_load_key: bool = event.is_action_pressed("quick_load") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_F9 or event.keycode == KEY_F8 or event.keycode == KEY_L
		)
	)

	if is_cancel_key:
		if modal_backdrop.visible:
			get_viewport().set_input_as_handled()
			if settings_confirm_dialog and settings_confirm_dialog.visible:
				_on_cancel_confirm_pressed()
			elif settings_dialog.visible:
				_on_try_close_settings()
			else:
				_close_all_modals()
	elif is_load_key:
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.save_exists("slot_1"):
			get_viewport().set_input_as_handled()
			save_mgr.load_game("slot_1")
