extends CanvasLayer

# Скрипт меню паузы во время игры (PauseMenu)
# Позволяет сохранять игру в слоты, загружать сохранения, менять настройки и возвращаться в главное меню

@onready var container: Control = $PauseContainer
@onready var modal_backdrop: ColorRect = $PauseContainer/Backdrop
@onready var menu_panel: PanelContainer = $PauseContainer/MenuPanel

# Кнопки главного меню паузы
@onready var btn_resume: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnResume
@onready var btn_clues: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnClues
@onready var btn_save: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnSave
@onready var btn_load: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnLoad
@onready var btn_settings: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnSettings
@onready var btn_main_menu: Button = $PauseContainer/MenuPanel/Margin/VBox/BtnMainMenu

# Модальное окно материалов дела и чертогов разума
@onready var clues_dialog: PanelContainer = $PauseContainer/CluesDialog
@onready var btn_tab_dossier: Button = $PauseContainer/CluesDialog/Margin/VBox/HeaderHBox/TabHeaderHBox/BtnTabDossier
@onready var btn_tab_mind_palace: Button = $PauseContainer/CluesDialog/Margin/VBox/HeaderHBox/TabHeaderHBox/BtnTabMindPalace
@onready var clues_counter: Label = $PauseContainer/CluesDialog/Margin/VBox/HeaderHBox/CountersHBox/CluesCounter
@onready var deductions_counter: Label = $PauseContainer/CluesDialog/Margin/VBox/HeaderHBox/CountersHBox/DeductionsCounter
@onready var clues_subtitle: Label = $PauseContainer/CluesDialog/Margin/VBox/Subtitle

# Вкладка Досье улик
@onready var dossier_view: Control = $PauseContainer/CluesDialog/Margin/VBox/DossierView
@onready var clue_list_container: VBoxContainer = $PauseContainer/CluesDialog/Margin/VBox/DossierView/LeftScroll/ClueListContainer
@onready var detail_icon: Label = $PauseContainer/CluesDialog/Margin/VBox/DossierView/RightDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailIcon
@onready var detail_title: Label = $PauseContainer/CluesDialog/Margin/VBox/DossierView/RightDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailTitleVBox/DetailTitle
@onready var detail_meta: Label = $PauseContainer/CluesDialog/Margin/VBox/DossierView/RightDetailPanel/DetailMargin/DetailVBox/DetailHeader/DetailTitleVBox/DetailMeta
@onready var detail_desc: Label = $PauseContainer/CluesDialog/Margin/VBox/DossierView/RightDetailPanel/DetailMargin/DetailVBox/DetailDescScroll/DetailDescVBox/DetailDesc
@onready var hint_text: Label = $PauseContainer/CluesDialog/Margin/VBox/DossierView/RightDetailPanel/DetailMargin/DetailVBox/DetailDescScroll/DetailDescVBox/HintBox/HintMargin/HintText

# Вкладка Чертоги разума
@onready var mind_palace_view: Control = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView
@onready var board_clue_list: VBoxContainer = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/BoardCluesCol/BoardScroll/BoardClueList
@onready var btn_reset_slots: Button = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/SynthesisHeader/BtnResetSlots
@onready var slot1_card: PanelContainer = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot1Card
@onready var slot1_icon: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot1Card/Slot1Margin/Slot1HBox/Slot1Icon
@onready var slot1_title: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot1Card/Slot1Margin/Slot1HBox/Slot1Title
@onready var btn_clear_slot1: Button = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot1Card/Slot1Margin/Slot1HBox/BtnClearSlot1
@onready var btn_synthesize: Button = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/ActionHBox/BtnSynthesize
@onready var slot2_card: PanelContainer = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot2Card
@onready var slot2_icon: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot2Card/Slot2Margin/Slot2HBox/Slot2Icon
@onready var slot2_title: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot2Card/Slot2Margin/Slot2HBox/Slot2Title
@onready var btn_clear_slot2: Button = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/Slot2Card/Slot2Margin/Slot2HBox/BtnClearSlot2
@onready var insight_title: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/InsightPanel/InsightMargin/InsightVBox/InsightTitle
@onready var insight_text: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/InsightPanel/InsightMargin/InsightVBox/InsightScroll/InsightText
@onready var insight_status: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/SynthesisCol/SynthesisMargin/SynthesisVBox/InsightPanel/InsightMargin/InsightVBox/InsightStatus
@onready var deductions_sub: Label = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/DeductionsCol/DeductionsSub
@onready var deductions_list: VBoxContainer = $PauseContainer/CluesDialog/Margin/VBox/MindPalaceView/DeductionsCol/DeductionsScroll/DeductionsList

@onready var btn_close_clues: Button = $PauseContainer/CluesDialog/Margin/VBox/FooterHBox/BtnCloseClues

var _selected_clue_id: String = ""
var _opened_via_clues_hotkey: bool = false
var _current_clues_tab: String = "dossier" # "dossier" или "mind_palace"
var _selected_slot1_clue_id: String = ""
var _selected_slot2_clue_id: String = ""
@onready var save_dialog: PanelContainer = $PauseContainer/SaveDialog
@onready var save_slot_container: VBoxContainer = $PauseContainer/SaveDialog/Margin/VBox/Scroll/SaveSlotContainer
@onready var btn_close_save: Button = $PauseContainer/SaveDialog/Margin/VBox/BtnCloseSave

@onready var load_dialog: PanelContainer = $PauseContainer/LoadDialog
@onready var load_slot_container: VBoxContainer = $PauseContainer/LoadDialog/Margin/VBox/Scroll/LoadSlotContainer
@onready var btn_close_load: Button = $PauseContainer/LoadDialog/Margin/VBox/BtnCloseLoad

@onready var settings_dialog: PanelContainer = $PauseContainer/SettingsDialog
@onready var tab_header: HBoxContainer = $PauseContainer/SettingsDialog/Margin/VBox/TabHeader
@onready var btn_tab_audio: Button = $PauseContainer/SettingsDialog/Margin/VBox/TabHeader/BtnTabAudio
@onready var btn_tab_text: Button = $PauseContainer/SettingsDialog/Margin/VBox/TabHeader/BtnTabText
@onready var btn_tab_controls: Button = $PauseContainer/SettingsDialog/Margin/VBox/TabHeader/BtnTabControls
@onready var audio_tab: VBoxContainer = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab
@onready var text_tab: VBoxContainer = $PauseContainer/SettingsDialog/Margin/VBox/TextTab
@onready var controls_tab: VBoxContainer = $PauseContainer/SettingsDialog/Margin/VBox/ControlsTab

@onready var slider_text_speed: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/TextTab/Grid/SpeedSlider
@onready var lbl_text_speed_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/TextTab/Grid/SpeedValue
@onready var slider_advance_delay: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/TextTab/Grid/DelaySlider
@onready var lbl_advance_delay_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/TextTab/Grid/DelayValue
@onready var check_auto_advance: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/TextTab/OptionsList/CheckAutoAdvance

@onready var slider_master: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/MasterSlider
@onready var lbl_master_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/MasterValue
@onready var slider_music: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/MusicSlider
@onready var lbl_music_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/MusicValue
@onready var slider_sfx: HSlider = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/SFXSlider
@onready var lbl_sfx_val: Label = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/Grid/SFXValue
@onready var check_fullscreen: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckFullscreen
@onready var check_vsync: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckVSync
@onready var check_crt: CheckBox = $PauseContainer/SettingsDialog/Margin/VBox/AudioTab/OptionsList/CheckCRT

@onready var keybind_list: VBoxContainer = $PauseContainer/SettingsDialog/Margin/VBox/ControlsTab/ScrollControls/KeybindList
@onready var btn_reset_keybinds: Button = $PauseContainer/SettingsDialog/Margin/VBox/ControlsTab/BtnResetKeybinds
@onready var btn_apply_settings: Button = $PauseContainer/SettingsDialog/Margin/VBox/SettingsFooter/BtnApplySettings
@onready var btn_close_settings: Button = $PauseContainer/SettingsDialog/Margin/VBox/SettingsFooter/BtnCloseSettings

# Модальное окно подтверждения настроек
@onready var settings_confirm_dialog: PanelContainer = $PauseContainer/SettingsConfirmDialog
@onready var btn_confirm_save: Button = $PauseContainer/SettingsConfirmDialog/Margin/VBox/HBox/BtnConfirmSave
@onready var btn_discard_save: Button = $PauseContainer/SettingsConfirmDialog/Margin/VBox/HBox/BtnDiscardSave
@onready var btn_cancel_confirm: Button = $PauseContainer/SettingsConfirmDialog/Margin/VBox/HBox/BtnCancelConfirm

# Toast уведомления
@onready var toast_panel: PanelContainer = $ToastNotification
@onready var toast_label: Label = $ToastNotification/Margin/ToastLabel

var toast_tween: Tween
var _has_unsaved_settings: bool = false
var _is_syncing_settings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_menu()
	if toast_panel:
		toast_panel.visible = false
		toast_panel.modulate.a = 0.0

	_connect_buttons()
	_connect_settings()

	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_signal("toast_requested"):
		save_mgr.toast_requested.connect(show_toast)

	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if clue_mgr and clue_mgr.has_signal("clues_updated"):
		clue_mgr.clues_updated.connect(_on_clues_updated)

var _rebinding_action: String = ""
var _rebinding_button: Button = null

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

	var is_clues_key: bool = event.is_action_pressed("toggle_clues") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_TAB or event.keycode == KEY_J
		)
	)
	if is_clues_key:
		var ui_dialogue: CanvasLayer = get_node_or_null("../UI") as CanvasLayer
		if ui_dialogue and ui_dialogue.get("_is_history_open"):
			return
		get_viewport().set_input_as_handled()
		toggle_clues_menu()
		return

	var is_mind_palace_key: bool = event.is_action_pressed("toggle_mind_palace") or (
		event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_M
	)
	if is_mind_palace_key:
		var ui_dialogue: CanvasLayer = get_node_or_null("../UI") as CanvasLayer
		if ui_dialogue and ui_dialogue.get("_is_history_open"):
			return
		get_viewport().set_input_as_handled()
		open_mind_palace()
		return

	var is_pause_key: bool = event.is_action_pressed("ui_cancel") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_ESCAPE or event.keycode == KEY_P
		)
	)
	var is_save_key: bool = event.is_action_pressed("quick_save") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_F5 or event.keycode == KEY_F6 or event.keycode == KEY_K
		)
	)
	var is_load_key: bool = event.is_action_pressed("quick_load") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_F9 or event.keycode == KEY_F8 or event.keycode == KEY_L
		)
	)

	if is_pause_key:
		# Если открыто окно истории реплик диалога [H], пусть Esc сначала закроет его
		var ui_dialogue: CanvasLayer = get_node_or_null("../UI") as CanvasLayer
		if ui_dialogue and ui_dialogue.get("_is_history_open"):
			return

		get_viewport().set_input_as_handled()
		if settings_confirm_dialog and settings_confirm_dialog.visible:
			_on_cancel_confirm_pressed()
		elif settings_dialog.visible:
			_on_try_close_settings()
		elif clues_dialog and clues_dialog.visible:
			_on_close_clues_pressed()
		elif save_dialog.visible or load_dialog.visible:
			_close_all_modals()
		else:
			toggle_pause()

	elif is_save_key:
		# Быстрое сохранение (F5 / K)
		get_viewport().set_input_as_handled()
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr:
			save_mgr.save_game("slot_1", "Быстрое сохранение [F5/K]")

	elif is_load_key:
		# Быстрая загрузка (F9 / L)
		get_viewport().set_input_as_handled()
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr:
			if save_mgr.save_exists("slot_1"):
				close_menu()
				save_mgr.load_game("slot_1")
			else:
				show_toast("⚠️ Нет сохранения в Слоте 1 [F9 / L]")

func close_menu() -> void:
	get_tree().paused = false
	container.visible = false
	_close_all_modals()

func toggle_pause() -> void:
	if get_tree().paused or container.visible:
		close_menu()
	else:
		get_tree().paused = true
		container.visible = true
		_close_all_modals()
		menu_panel.visible = true
		btn_resume.grab_focus()

func _connect_buttons() -> void:
	btn_resume.pressed.connect(func(): close_menu())
	btn_clues.pressed.connect(_on_clues_pressed)
	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)

	btn_close_clues.pressed.connect(_on_close_clues_pressed)
	btn_close_save.pressed.connect(_close_all_modals)
	btn_close_load.pressed.connect(_close_all_modals)
	btn_close_settings.pressed.connect(_on_try_close_settings)
	btn_apply_settings.pressed.connect(_on_apply_settings_pressed)

	btn_confirm_save.pressed.connect(_on_confirm_save_pressed)
	btn_discard_save.pressed.connect(_on_discard_save_pressed)
	btn_cancel_confirm.pressed.connect(_on_cancel_confirm_pressed)

	if btn_tab_dossier:
		btn_tab_dossier.pressed.connect(func(): _switch_clues_tab("dossier"))
	if btn_tab_mind_palace:
		btn_tab_mind_palace.pressed.connect(func(): _switch_clues_tab("mind_palace"))
	if btn_reset_slots:
		btn_reset_slots.pressed.connect(_clear_both_slots)
	if btn_clear_slot1:
		btn_clear_slot1.pressed.connect(func(): _clear_slot(1))
	if btn_clear_slot2:
		btn_clear_slot2.pressed.connect(func(): _clear_slot(2))
	if btn_synthesize:
		btn_synthesize.pressed.connect(_on_synthesize_pressed)

	_bind_sound_feedback([
		btn_resume, btn_clues, btn_save, btn_load, btn_settings, btn_main_menu,
		btn_close_clues, btn_close_save, btn_close_load, btn_apply_settings, btn_close_settings,
		btn_tab_audio, btn_tab_text, btn_tab_controls, btn_reset_keybinds,
		btn_confirm_save, btn_discard_save, btn_cancel_confirm,
		btn_tab_dossier, btn_tab_mind_palace, btn_reset_slots, btn_clear_slot1, btn_clear_slot2, btn_synthesize
	])

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
	_switch_settings_tab("audio")
	_is_syncing_settings = true
	_sync_settings_ui()
	_is_syncing_settings = false
	_has_unsaved_settings = false
	_update_save_button_state()
	menu_panel.visible = false
	settings_dialog.visible = true

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _close_all_modals() -> void:
	if clues_dialog:
		clues_dialog.visible = false
	save_dialog.visible = false
	load_dialog.visible = false
	settings_dialog.visible = false
	if settings_confirm_dialog:
		settings_confirm_dialog.visible = false
	menu_panel.visible = true
	_opened_via_clues_hotkey = false

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
	hbox.add_theme_constant_override("separation", 12)
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
					close_menu()
					save_mgr.load_game(slot_id)
			)
			actions_box.add_child(btn_action)
		else:
			var lbl_empty: Label = Label.new()
			lbl_empty.text = "—"
			actions_box.add_child(lbl_empty)

	return card

func _switch_settings_tab(tab_name: String) -> void:
	_cancel_key_rebind()
	if audio_tab:
		audio_tab.visible = (tab_name == "audio")
	if text_tab:
		text_tab.visible = (tab_name == "text")
	if controls_tab:
		controls_tab.visible = (tab_name == "controls")

	if btn_tab_audio:
		btn_tab_audio.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "audio" else Color(0.65, 0.7, 0.8, 0.7)
	if btn_tab_text:
		btn_tab_text.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "text" else Color(0.65, 0.7, 0.8, 0.7)
	if btn_tab_controls:
		btn_tab_controls.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "controls" else Color(0.65, 0.7, 0.8, 0.7)

	if tab_name == "controls":
		_populate_keybinds()

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

func _connect_settings() -> void:
	btn_tab_audio.pressed.connect(func(): _switch_settings_tab("audio"))
	if btn_tab_text:
		btn_tab_text.pressed.connect(func(): _switch_settings_tab("text"))
	btn_tab_controls.pressed.connect(func(): _switch_settings_tab("controls"))

	if slider_text_speed:
		slider_text_speed.value_changed.connect(func(val: float):
			var mgr: Node = get_node_or_null("/root/SettingsManager")
			if mgr:
				mgr.set_text_speed(int(val))
				if lbl_text_speed_val:
					lbl_text_speed_val.text = mgr.get_speed_title()
			_mark_settings_dirty()
		)
	if slider_advance_delay:
		slider_advance_delay.value_changed.connect(func(val: float):
			var mgr: Node = get_node_or_null("/root/SettingsManager")
			if mgr:
				mgr.set_auto_advance_delay(val)
				if lbl_advance_delay_val:
					lbl_advance_delay_val.text = "%.1f сек" % val
			_mark_settings_dirty()
		)
	if check_auto_advance:
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
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		row.add_child(margin)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		margin.add_child(hbox)

		var lbl: Label = Label.new()
		lbl.text = act_title
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var btn_bind: Button = Button.new()
		btn_bind.custom_minimum_size = Vector2(140, 28)
		btn_bind.text = "[ " + mgr.get_action_key_name(act_name) + " ]"
		btn_bind.add_theme_font_size_override("font_size", 12)

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

	if slider_text_speed and mgr.has_method("get_speed_title"):
		slider_text_speed.value = float(mgr.text_speed_mode)
		if lbl_text_speed_val:
			lbl_text_speed_val.text = mgr.get_speed_title()
	if slider_advance_delay:
		slider_advance_delay.value = mgr.auto_advance_delay
		if lbl_advance_delay_val:
			lbl_advance_delay_val.text = "%.1f сек" % mgr.auto_advance_delay
	if check_auto_advance:
		check_auto_advance.button_pressed = mgr.auto_advance

	_populate_keybinds()

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

# ========================================================
# Панель материалов дела и чертогов разума (CluesDialog)
# ========================================================

func toggle_clues_menu() -> void:
	if not is_node_ready():
		return
	if container and container.visible and clues_dialog and clues_dialog.visible:
		if _opened_via_clues_hotkey:
			close_menu()
		else:
			_close_all_modals()
	else:
		_opened_via_clues_hotkey = not (container and container.visible)
		get_tree().paused = true
		if container:
			container.visible = true
		_on_clues_pressed()

func open_mind_palace() -> void:
	if not is_node_ready():
		return
	if container and container.visible and clues_dialog and clues_dialog.visible and _current_clues_tab == "mind_palace":
		close_menu()
	else:
		_opened_via_clues_hotkey = not (container and container.visible)
		get_tree().paused = true
		if container:
			container.visible = true
		_on_clues_pressed()
		_switch_clues_tab("mind_palace")

func _on_clues_pressed() -> void:
	if not is_node_ready():
		return
	if menu_panel: menu_panel.visible = false
	if save_dialog: save_dialog.visible = false
	if load_dialog: load_dialog.visible = false
	if settings_dialog: settings_dialog.visible = false
	if settings_confirm_dialog:
		settings_confirm_dialog.visible = false
	if clues_dialog: clues_dialog.visible = true
	_switch_clues_tab(_current_clues_tab)
	if btn_close_clues:
		btn_close_clues.grab_focus()

func _on_close_clues_pressed() -> void:
	if _opened_via_clues_hotkey:
		close_menu()
	else:
		_close_all_modals()

func _switch_clues_tab(tab_name: String) -> void:
	_current_clues_tab = tab_name
	if dossier_view:
		dossier_view.visible = (tab_name == "dossier")
	if mind_palace_view:
		mind_palace_view.visible = (tab_name == "mind_palace")

	if btn_tab_dossier:
		btn_tab_dossier.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "dossier" else Color(0.65, 0.7, 0.8, 0.7)
	if btn_tab_mind_palace:
		btn_tab_mind_palace.modulate = Color(1.0, 1.0, 1.0, 1.0) if tab_name == "mind_palace" else Color(0.65, 0.7, 0.8, 0.7)

	if clues_subtitle:
		if tab_name == "dossier":
			clues_subtitle.text = "Все обнаруженные сюжетные улики, детали дебоша и подсказки к дальнейшим действиям"
		else:
			clues_subtitle.text = "Чертоги разума: сопоставляйте найденные зацепки для выстраивания логических цепочек и озарений"

	_update_clues_and_deductions_counters()

	if tab_name == "dossier":
		_populate_clues_ui()
	else:
		_populate_mind_palace_ui()

func _on_clues_updated() -> void:
	if clues_dialog and clues_dialog.visible:
		_update_clues_and_deductions_counters()
		if _current_clues_tab == "dossier":
			_populate_clues_ui()
		else:
			_populate_mind_palace_ui()

func _update_clues_and_deductions_counters() -> void:
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if not clue_mgr:
		return

	var discovered_count: int = clue_mgr.get_discovered_count()
	var total_count: int = clue_mgr.get_total_count()
	var unlocked_ded_count: int = clue_mgr.get_unlocked_deductions_count()
	var total_ded_count: int = clue_mgr.get_total_deductions_count()

	if clues_counter:
		clues_counter.text = "🔍 Улики: %d / %d" % [discovered_count, total_count]
	if deductions_counter:
		deductions_counter.text = "🧠 Выводы: %d / %d" % [unlocked_ded_count, total_ded_count]
	if deductions_sub:
		deductions_sub.text = "Сформировано выводов: %d из %d" % [unlocked_ded_count, total_ded_count]

# --------------------------------------------------------
# Вкладка 1: Досье улик (Dossier)
# --------------------------------------------------------

func _populate_clues_ui() -> void:
	if not clue_list_container:
		return

	for child in clue_list_container.get_children():
		child.queue_free()

	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if not clue_mgr:
		return

	var all_clues: Array[Dictionary] = clue_mgr.get_all_clues()
	var selected_clue_to_show: Dictionary = {}

	for clue in all_clues:
		var c_id: String = clue.get("id", "")
		var is_discovered: bool = bool(clue.get("discovered", false))

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if is_discovered:
			btn.text = "%s  %s\n[%s • %s]" % [
				clue.get("icon", ""),
				clue.get("title", ""),
				clue.get("category", "Улика"),
				clue.get("location", "")
			]
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
		else:
			btn.text = "❓  Неизвестная зацепка\n[ Не исследовано ]"
			btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.75))

		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)

		btn.pressed.connect(func():
			_selected_clue_id = c_id
			_show_clue_detail(clue)
			var s_mgr: Node = get_node_or_null("/root/SoundManager")
			if s_mgr and s_mgr.has_method("play_click"):
				s_mgr.play_click()
		)
		btn.mouse_entered.connect(func():
			var s_mgr: Node = get_node_or_null("/root/SoundManager")
			if s_mgr and s_mgr.has_method("play_hover"):
				s_mgr.play_hover()
		)

		clue_list_container.add_child(btn)

		if selected_clue_to_show.is_empty():
			if _selected_clue_id != "" and c_id == _selected_clue_id:
				selected_clue_to_show = clue
			elif _selected_clue_id == "" and is_discovered:
				selected_clue_to_show = clue

	if selected_clue_to_show.is_empty() and not all_clues.is_empty():
		selected_clue_to_show = all_clues[0]

	if not selected_clue_to_show.is_empty():
		_selected_clue_id = selected_clue_to_show.get("id", "")
		_show_clue_detail(selected_clue_to_show)

func _show_clue_detail(clue: Dictionary) -> void:
	var is_discovered: bool = bool(clue.get("discovered", false))

	if is_discovered:
		if detail_icon:
			detail_icon.text = clue.get("icon", "🔍")
		if detail_title:
			detail_title.text = clue.get("title", "")
			detail_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
		if detail_meta:
			var time_str: String = clue.get("discovered_at", "")
			detail_meta.text = "Категория: %s | Локация: %s%s" % [
				clue.get("category", "Улика"),
				clue.get("location", ""),
				(" | Найдено в " + time_str) if time_str != "" else ""
			]
		if detail_desc:
			detail_desc.text = clue.get("description", "")
		if hint_text:
			hint_text.text = "💡 ПОДСКАЗКА: " + clue.get("hint", "")
			var hint_panel: Control = hint_text.get_parent().get_parent() as Control
			if hint_panel:
				hint_panel.visible = true
	else:
		if detail_icon:
			detail_icon.text = "❓"
		if detail_title:
			detail_title.text = "Неисследованная зацепка"
			detail_title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.8))
		if detail_meta:
			detail_meta.text = "Статус: Улика ещё не обнаружена в комнате"
		if detail_desc:
			detail_desc.text = "В этой части квартиры есть важный предмет или след, связанный с событиями прошлой ночи. Внимательно исследуйте квартиру и взаимодействуйте с окружением клавишей [E / Пробел]."
		if hint_text:
			hint_text.text = "💡 ПОДСКАЗКА: Осмотрите пол, стены и подозрительные предметы."
			var hint_panel: Control = hint_text.get_parent().get_parent() as Control
			if hint_panel:
				hint_panel.visible = true

# --------------------------------------------------------
# Вкладка 2: Чертоги разума (Mind Palace)
# --------------------------------------------------------

func _populate_mind_palace_ui() -> void:
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if not clue_mgr:
		return

	# 1. Заполняем левую колонку доступных улик
	if board_clue_list:
		for child in board_clue_list.get_children():
			child.queue_free()

		var all_clues: Array[Dictionary] = clue_mgr.get_all_clues()
		var discovered_count: int = 0

		for clue in all_clues:
			var c_id: String = clue.get("id", "")
			var is_discovered: bool = bool(clue.get("discovered", false))

			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(0, 46)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 11)

			if is_discovered:
				discovered_count += 1
				var status_prefix: String = "[📌] "
				var font_col: Color = Color(0.92, 0.95, 1.0, 1.0)

				if c_id == _selected_slot1_clue_id:
					status_prefix = "[СЛОТ 1 ⚡] "
					font_col = Color(0.2, 0.85, 1.0, 1.0)
				elif c_id == _selected_slot2_clue_id:
					status_prefix = "[СЛОТ 2 ⚡] "
					font_col = Color(1.0, 0.45, 0.75, 1.0)

				btn.text = "%s%s %s\n[%s]" % [
					status_prefix,
					clue.get("icon", ""),
					clue.get("title", ""),
					clue.get("location", "")
				]
				btn.add_theme_color_override("font_color", font_col)

				btn.pressed.connect(func():
					_select_clue_for_mind_palace(c_id)
				)
				btn.mouse_entered.connect(func():
					var s_mgr: Node = get_node_or_null("/root/SoundManager")
					if s_mgr and s_mgr.has_method("play_hover"):
						s_mgr.play_hover()
				)
			else:
				btn.text = "❓  Неизвестная улика\n[Не исследовано в комнате]"
				btn.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6, 0.6))
				btn.disabled = true

			board_clue_list.add_child(btn)

		if discovered_count == 0:
			var empty_lbl: Label = Label.new()
			empty_lbl.text = "В комнате ещё не найдено ни одной улик.\nОсмотрите помещение клавишей [E]."
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			board_clue_list.add_child(empty_lbl)

	# 2. Обновляем карточки слотов дедукции
	_update_mind_palace_slots_ui()

	# 3. Заполняем правую колонку журнала озарений
	if deductions_list:
		for child in deductions_list.get_children():
			child.queue_free()

		var all_deductions: Array[Dictionary] = clue_mgr.get_all_deductions()
		var unlocked_count: int = 0

		for d in all_deductions:
			var is_unlocked: bool = bool(d.get("unlocked", false))
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(0, 48)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 11)

			if is_unlocked:
				unlocked_count += 1
				btn.text = "%s  %s\n[✓ В %s • Тревога %d%%]" % [
					d.get("icon", "💡"),
					d.get("title", ""),
					d.get("unlocked_at", ""),
					int(d.get("paranoia_relief", 15.0)) * -1
				]
				btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
				btn.pressed.connect(func():
					_show_deduction_inspection(d)
				)
				btn.mouse_entered.connect(func():
					var s_mgr: Node = get_node_or_null("/root/SoundManager")
					if s_mgr and s_mgr.has_method("play_hover"):
						s_mgr.play_hover()
				)
			else:
				btn.text = "🔒  Нераскрытое озарение\n[Сопоставьте две зацепки]"
				btn.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6, 0.5))
				btn.disabled = true

			deductions_list.add_child(btn)

		if unlocked_count == 0:
			var hint_lbl: Label = Label.new()
			hint_lbl.text = "Пока нет сформулированных выводов.\n\nПопробуйте сопоставить, например, время на смятом чеке из бара с надписью на зеркале."
			hint_lbl.add_theme_font_size_override("font_size", 11)
			hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.8))
			hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			deductions_list.add_child(hint_lbl)

func _update_mind_palace_slots_ui() -> void:
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if not clue_mgr:
		return

	# Слот 1
	if _selected_slot1_clue_id != "":
		var c1: Dictionary = clue_mgr.get_clue(_selected_slot1_clue_id)
		if slot1_icon: slot1_icon.text = c1.get("icon", "🔍")
		if slot1_title:
			slot1_title.text = c1.get("title", _selected_slot1_clue_id)
			slot1_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
		if btn_clear_slot1: btn_clear_slot1.visible = true
	else:
		if slot1_icon: slot1_icon.text = "❓"
		if slot1_title:
			slot1_title.text = "Выберите первую улику слева..."
			slot1_title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.6))
		if btn_clear_slot1: btn_clear_slot1.visible = false

	# Слот 2
	if _selected_slot2_clue_id != "":
		var c2: Dictionary = clue_mgr.get_clue(_selected_slot2_clue_id)
		if slot2_icon: slot2_icon.text = c2.get("icon", "🔍")
		if slot2_title:
			slot2_title.text = c2.get("title", _selected_slot2_clue_id)
			slot2_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.75, 1.0))
		if btn_clear_slot2: btn_clear_slot2.visible = true
	else:
		if slot2_icon: slot2_icon.text = "❓"
		if slot2_title:
			slot2_title.text = "Выберите вторую улику слева..."
			slot2_title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.6))
		if btn_clear_slot2: btn_clear_slot2.visible = false

	# Кнопка сопоставления
	if btn_synthesize:
		var can_synthesize: bool = (_selected_slot1_clue_id != "" and _selected_slot2_clue_id != "" and _selected_slot1_clue_id != _selected_slot2_clue_id)
		btn_synthesize.disabled = not can_synthesize
		if can_synthesize:
			btn_synthesize.text = "⚡  СОПОСТАВИТЬ ЗАЦЕПКИ В ЧЕРТОГАХ"
			btn_synthesize.modulate = Color(1.1, 1.1, 1.0, 1.0)
		else:
			btn_synthesize.text = "⚡  ВЫБЕРИТЕ 2 РАЗНЫЕ ЗАЦЕПКИ"
			btn_synthesize.modulate = Color(0.7, 0.75, 0.8, 0.65)

func _select_clue_for_mind_palace(clue_id: String) -> void:
	if _selected_slot1_clue_id == clue_id:
		_selected_slot1_clue_id = ""
	elif _selected_slot2_clue_id == clue_id:
		_selected_slot2_clue_id = ""
	elif _selected_slot1_clue_id == "":
		_selected_slot1_clue_id = clue_id
	elif _selected_slot2_clue_id == "":
		_selected_slot2_clue_id = clue_id
	else:
		_selected_slot2_clue_id = clue_id

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_clue_pin"):
		sound_mgr.play_clue_pin()

	_populate_mind_palace_ui()

func _clear_slot(slot_idx: int) -> void:
	if slot_idx == 1:
		_selected_slot1_clue_id = ""
	elif slot_idx == 2:
		_selected_slot2_clue_id = ""

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()

	_populate_mind_palace_ui()

func _clear_both_slots() -> void:
	_selected_slot1_clue_id = ""
	_selected_slot2_clue_id = ""

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_cancel"):
		sound_mgr.play_cancel()

	_populate_mind_palace_ui()

func _on_synthesize_pressed() -> void:
	if _selected_slot1_clue_id == "" or _selected_slot2_clue_id == "":
		return

	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if not clue_mgr:
		return

	var result: Dictionary = clue_mgr.connect_clues(_selected_slot1_clue_id, _selected_slot2_clue_id)

	if result.get("success", false):
		var d: Dictionary = result.get("deduction", {})
		if insight_title:
			insight_title.text = "💡 ЭВРИКА: " + d.get("title", "")
			insight_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		if insight_text:
			insight_text.text = d.get("insight", "")
		if insight_status:
			insight_status.text = "🫀 " + d.get("narrative_effect", "")
			insight_status.visible = true

		show_toast("🧩 Чертоги разума: «%s»!" % d.get("title", ""))
	elif result.get("already_unlocked", false):
		var d: Dictionary = result.get("deduction", {})
		if insight_title:
			insight_title.text = "ℹ️ УЖЕ СФОРМИРОВАНО: " + d.get("title", "")
			insight_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
		if insight_text:
			insight_text.text = d.get("insight", "")
		if insight_status:
			insight_status.text = "Логический вывод уже зафиксирован в материалах дела."
			insight_status.visible = true
	else:
		if insight_title:
			insight_title.text = "❌ НЕСТЫКОВКА ЗАЦЕПОК"
			insight_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.5, 1.0))
		if insight_text:
			insight_text.text = str(result.get("reason", "Связь между этими зацепками не обнаружена."))
		if insight_status:
			insight_status.visible = false

	_update_clues_and_deductions_counters()
	_populate_mind_palace_ui()

func _show_deduction_inspection(deduction: Dictionary) -> void:
	if insight_title:
		insight_title.text = "🔍 ВЫВОД: " + deduction.get("title", "")
		insight_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	if insight_text:
		insight_text.text = deduction.get("insight", "")
	if insight_status:
		insight_status.text = "🫀 " + deduction.get("narrative_effect", "") + " (Сформировано в " + deduction.get("unlocked_at", "") + ")"
		insight_status.visible = true

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_click"):
		sound_mgr.play_click()

