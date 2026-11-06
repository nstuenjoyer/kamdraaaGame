extends Control

# Скрипт главного меню (MainMenu)
# Отвечает за навигацию, диалоги сохранения/загрузки, настройки и экран "Об игре"

const GAME_SCENE_PATH: String = "res://scenes/chapter_1_3d/apartment.tscn"

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
var modal_tween: Tween
var return_focus: Control
var _composition_ready: bool = false
var _has_unsaved_settings: bool = false
var _is_syncing_settings: bool = false

var _neon_timer: float = 0.0
var _neon_flicker_duration: float = 0.0
var _neon_flicker_factor: float = 1.0

func _ready() -> void:
	ParanoiaManager.is_active = false
	SoundManager.stop_heartbeat()
	SoundManager.start_menu_rain()
	theme = NoirUI.make_theme()
	NoirUI.restyle_tree(self)
	_build_composition()
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

func _exit_tree() -> void:
	SoundManager.stop_menu_rain()

func _update_load_button_state() -> void:
	if btn_load:
		btn_load.text = "Загрузить игру"
		btn_load.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	_neon_timer += delta
	var t: float = _neon_timer

	# Плавная базовая синусоидальная пульсация неонового свечения
	var pulse: float = 0.92 + 0.16 * sin(t * 1.7)

	# Спонтанные микро-сбои и перебои напряжения неоновой трубки
	if _neon_flicker_duration > 0.0:
		_neon_flicker_duration -= delta
		_neon_flicker_factor = randf_range(0.7, 1.08)
	else:
		_neon_flicker_factor = 1.0
		# Случайный запуск короткого сбоя неоновой лампы
		if randf() < 1.0 - exp(-0.25 * delta):
			_neon_flicker_duration = randf_range(0.06, 0.18)

	var total_intensity: float = pulse * _neon_flicker_factor

	# Гармонизация мерцания заголовка Kamdraaa и шейдера дождя за окном
	if title_label:
		title_label.modulate = Color.WHITE

	if rain_overlay and rain_overlay.material is ShaderMaterial:
		(rain_overlay.material as ShaderMaterial).set_shader_parameter("neon_flicker", total_intensity)

func _build_composition() -> void:
	var composition: Control = Control.new()
	composition.set_script(preload("res://scripts/menu_composition.gd"))
	composition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(composition)
	move_child(composition, $Content.get_index())
	var artwork: TextureRect = TextureRect.new()
	artwork.texture = load("res://assets/textures/menu/apartment_night.png")
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(artwork)
	move_child(artwork, $RainOverlay.get_index())
	rain_overlay.material = null
	rain_overlay.color = Color(0,0,0,0)
	$RainOverlay/GlassRain.restrict_to_window()
	$Vignette.color = Color(0.02, 0.025, 0.03, 0.12)
	$Content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	$Content.size = Vector2(1280,720)
	$Content/Header.position = Vector2(80, 122)
	$Content/Header.size = Vector2(600, 180)
	$Content/Header.add_theme_constant_override("separation", 16)
	$Content/Header/Category.text = "ПСИХОЛОГИЧЕСКИЙ ТРИЛЛЕР"
	$Content/Header/Category.add_theme_font_size_override("font_size", 12)
	$Content/Header/Category.add_theme_color_override("font_color", NoirUI.ACCENT)
	title_label.add_theme_font_override("font", NoirUI.title_font())
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", NoirUI.TEXT)
	$Content/Header/Subtitle.text = "I   /   Тёмная квартира"
	$Content/Header/Subtitle.add_theme_color_override("font_color", NoirUI.MUTED)
	$Content/Header/Subtitle.add_theme_font_size_override("font_size", 20)
	$Content/Divider.visible = false
	$Content/MenuButtons.position = Vector2(80, 352)
	$Content/MenuButtons.size = Vector2(330, 230)
	$Content/MenuButtons.add_theme_constant_override("separation", 10)
	btn_play.text = "Играть"
	btn_load.text = "Загрузить игру"
	btn_settings.text = "Настройки"
	btn_about.text = "Об игре"
	btn_quit.text = "Выйти"
	for index: int in 3:
		var entry: Button = [btn_play,btn_load,btn_settings][index]
		entry.custom_minimum_size.y = 50
		entry.add_theme_font_size_override("font_size",20)
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBoxFlat = NoirUI.primary_style(state) if index == 0 else NoirUI.action_style(state)
			style.content_margin_left = 54
			entry.add_theme_stylebox_override(state,style)
		for color_name: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			entry.add_theme_color_override(color_name,NoirUI.INK if index == 0 else NoirUI.TEXT)
		var number: Label = Label.new()
		number.text = "%02d" % (index+1)
		number.position = Vector2(17,17)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.add_theme_font_size_override("font_size",12)
		number.add_theme_color_override("font_color",NoirUI.INK if index == 0 else NoirUI.MUTED)
		entry.add_child(number)
	var secondary: HBoxContainer = HBoxContainer.new()
	secondary.add_theme_constant_override("separation",24)
	$Content/MenuButtons.add_child(secondary)
	btn_about.reparent(secondary)
	btn_quit.reparent(secondary)
	for entry: Button in [btn_about,btn_quit]:
		entry.custom_minimum_size = Vector2(0,36)
		entry.add_theme_font_size_override("font_size",16)
		entry.add_theme_color_override("font_color",NoirUI.MUTED)
	$Content/FooterInfo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	$Content/FooterInfo.position = Vector2(80, 639)
	$Content/FooterInfo.text = "↑ ↓   выбор        Enter   подтвердить"
	$Content/FooterInfo.add_theme_color_override("font_color", NoirUI.MUTED)
	$Content/FooterInfo.add_theme_font_size_override("font_size", 13)
	_composition_ready = true
	resized.connect(_layout_frontend)
	_layout_frontend()
	btn_restore_saves.visible = false
	settings_dialog.offset_left = -350
	settings_dialog.offset_right = 350
	settings_dialog.offset_top = -310
	settings_dialog.offset_bottom = 310
	settings_dialog.custom_minimum_size = Vector2(700, 620)
	settings_dialog.pivot_offset = Vector2(350, 310)
	$Modals/SettingsDialog/Margin/VBox/ControlsTab/ScrollControls.custom_minimum_size.y = 310
	for entry: Array in [[play_dialog,"Продолжить историю","ИГРА"],[load_dialog,"Сохранения","ПРОГРЕСС"],[settings_dialog,"Настройки","ПАРАМЕТРЫ"],[about_dialog,"Об игре","KAMDRAAA"]]:
		var panel: PanelContainer = entry[0]
		var box: VBoxContainer = panel.get_node("Margin/VBox")
		var heading: Label = box.get_node("Title")
		heading.text = entry[1]
		var kicker: Label = Label.new()
		kicker.text = entry[2]
		kicker.add_theme_font_size_override("font_size",11)
		kicker.add_theme_color_override("font_color",NoirUI.ACCENT)
		box.add_child(kicker)
		box.move_child(kicker,0)
	btn_tab_text.text = "Текст"
	btn_tab_audio.text = "Звук и экран"
	$Modals/SettingsConfirmDialog/Margin/VBox/Title.text = "Несохранённые изменения"
	for primary: Button in [btn_apply_settings,btn_continue,btn_confirm_save]:
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			primary.add_theme_stylebox_override(state,NoirUI.primary_style(state))
		for color_name: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			primary.add_theme_color_override(color_name,NoirUI.INK)
	var about_text: RichTextLabel = $Modals/AboutDialog/Margin/VBox/AboutText
	about_text.text = "[b]Тёмная квартира[/b]\n\nДаша приходит в себя в собственной квартире. Света нет, телефон разряжен, а вчерашний вечер почти стёрся из памяти.\n\nИсследуйте комнаты, читайте записки и проверяйте свои догадки. Тревога меняет восприятие: не всему увиденному можно доверять.\n\n[b]Управление[/b]\nWASD / стрелки — движение\nE — взаимодействие\nI — сумка   /   J — дневник   /   M — план\nEsc — пауза\n\nПривязки клавиш можно изменить в настройках."
	about_text.add_theme_font_size_override("normal_font_size", 18)
	modal_backdrop.color = Color(0.025, 0.03, 0.025, 0.88)
	for panel: PanelContainer in [play_dialog, load_dialog, settings_dialog, about_dialog, settings_confirm_dialog]:
		panel.add_theme_stylebox_override("panel", NoirUI.frame_style(12))
	if rain_overlay.material is ShaderMaterial:
		var material: ShaderMaterial = rain_overlay.material as ShaderMaterial
		material.set_shader_parameter("city_glow_cyan", Color(0.19, 0.27, 0.23, 0.45))
		material.set_shader_parameter("city_glow_magenta", Color(0.2, 0.22, 0.16, 0.4))
		material.set_shader_parameter("city_glow_amber", Color(0.52, 0.43, 0.25, 0.3))

func _layout_frontend() -> void:
	if not _composition_ready: return
	var factor: float = minf(size.x/1280.0,size.y/720.0)
	$Content.scale = Vector2(factor,factor)
	$Content.position = (size-Vector2(1280,720)*factor)*0.5
	for panel: PanelContainer in [play_dialog,load_dialog,settings_dialog,about_dialog,settings_confirm_dialog]:
		panel.scale = Vector2(minf(1.0,(size.y-36.0)/620.0),minf(1.0,(size.y-36.0)/620.0))


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
		btn_tab_audio, btn_tab_text, btn_tab_controls, btn_reset_keybinds,
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
	var exists: bool = info.get("exists",false)
	var style: StyleBoxFlat = NoirUI.surface(NoirUI.PANEL if exists else Color(0,0,0,0),16)
	style.border_width_bottom = 1
	style.border_color = NoirUI.LINE
	card.add_theme_stylebox_override("panel",style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	card.add_child(row)
	var number: Label = Label.new()
	number.text = slot_id.trim_prefix("slot_").pad_zeros(2) if slot_id != "autosave" else "A"
	number.custom_minimum_size.x = 32
	number.add_theme_font_size_override("font_size",24)
	number.add_theme_font_override("font",NoirUI.title_font())
	number.add_theme_color_override("font_color",NoirUI.ACCENT if exists else NoirUI.MUTED)
	row.add_child(number)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",6)
	row.add_child(text)
	var title: Label = Label.new()
	title.text = info.get("title",slot_id)
	title.add_theme_font_size_override("font_size",18)
	text.add_child(title)
	var meta: Label = Label.new()
	meta.text = "%s\n%s" % [info.get("location","Тёмная квартира"),info.get("timestamp","")] if exists else "Нет сохранения"
	if exists and not info.get("compatible",false): meta.text += "\nСохранение прежней версии"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_color_override("font_color",NoirUI.MUTED)
	meta.add_theme_font_size_override("font_size",14)
	text.add_child(meta)
	if exists:
		var actions: VBoxContainer = VBoxContainer.new()
		row.add_child(actions)
		var load_button: Button = Button.new()
		load_button.text = "Продолжить"
		load_button.disabled = not info.get("compatible",false)
		load_button.custom_minimum_size = Vector2(128,38)
		load_button.pressed.connect(func() -> void: SaveManager.load_game(slot_id))
		actions.add_child(load_button)
		var erase: Button = Button.new()
		erase.text = "Удалить…"
		erase.disabled = not info.get("compatible",false)
		erase.custom_minimum_size.y = 32
		erase.add_theme_font_size_override("font_size",14)
		erase.add_theme_color_override("font_color",NoirUI.MUTED)
		erase.pressed.connect(func() -> void: _confirm_delete_slot(slot_id))
		actions.add_child(erase)
		_bind_sound_feedback([load_button,erase])
	return card

func _confirm_delete_slot(slot_id: String) -> void:
	var confirmation: ConfirmationDialog = ConfirmationDialog.new()
	confirmation.title = "Удалить сохранение?"
	confirmation.dialog_text = "Этот слот будет удалён. Остальные сохранения останутся."
	confirmation.ok_button_text = "Удалить"
	confirmation.cancel_button_text = "Отмена"
	confirmation.theme = theme
	add_child(confirmation)
	confirmation.confirmed.connect(func() -> void:
		SaveManager.delete_save(slot_id)
		_update_load_button_state()
		confirmation.queue_free()
	)
	confirmation.canceled.connect(confirmation.queue_free)
	_bind_sound_feedback([confirmation.get_ok_button(),confirmation.get_cancel_button()])
	confirmation.popup_centered(Vector2i(440,180))

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
		btn_apply_settings.text = "Сохранить изменения *"
		btn_apply_settings.modulate = NoirUI.ACCENT
	else:
		btn_apply_settings.text = "Сохранить настройки"
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
	_open_modal(settings_confirm_dialog)
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
	_open_modal(settings_dialog)
	if btn_close_settings:
		btn_close_settings.grab_focus()

func _switch_settings_tab(tab_name: String) -> void:
	_cancel_key_rebind()
	audio_tab.visible = (tab_name == "audio")
	text_tab.visible = (tab_name == "text")
	controls_tab.visible = (tab_name == "controls")

	var tabs: Array[Button] = [btn_tab_audio, btn_tab_text, btn_tab_controls]
	for index: int in tabs.size():
		var active: bool = ["audio", "text", "controls"][index] == tab_name
		tabs[index].modulate = Color.WHITE
		tabs[index].add_theme_stylebox_override("normal", NoirUI.tab_style(active))
		tabs[index].add_theme_color_override("font_color", NoirUI.ACCENT if active else NoirUI.MUTED)

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
		_bind_sound_feedback([btn_bind])
		hbox.add_child(btn_bind)

		NoirUI.restyle_tree(row)
		row.add_theme_stylebox_override("panel", NoirUI.surface(NoirUI.INK, 0))
		btn_bind.custom_minimum_size.y = 36
		keybind_list.add_child(row)

func _start_key_rebind(action_name: String, btn: Button) -> void:
	if _rebinding_action != "":
		_cancel_key_rebind()
	_rebinding_action = action_name
	_rebinding_button = btn
	btn.text = "Нажмите клавишу…"
	btn.modulate = NoirUI.ACCENT

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
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and $Content.is_ancestor_of(focused): return_focus = focused
	_close_all_modals(true)
	$Content.visible = false
	modal_backdrop.visible = true
	target_dialog.visible = true
	_layout_frontend()
	target_dialog.modulate.a = 0.0

	modal_tween = create_tween().set_parallel(true)
	var tween: Tween = modal_tween
	tween.tween_property(modal_backdrop, "modulate:a", 1.0, 0.2)
	tween.tween_property(target_dialog, "modulate:a", 1.0, 0.2)
	for candidate: Node in target_dialog.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and not candidate.disabled:
			candidate.grab_focus()
			break

func _close_all_modals(instant: bool = false) -> void:
	if modal_tween and modal_tween.is_valid(): modal_tween.kill()
	$Content.visible = true
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

	modal_tween = create_tween().set_parallel(true)
	var tween: Tween = modal_tween
	tween.tween_property(modal_backdrop, "modulate:a", 0.0, 0.15)
	for d in [play_dialog, load_dialog, settings_dialog, settings_confirm_dialog, about_dialog]:
		if d and d.visible:
			tween.tween_property(d, "modulate:a", 0.0, 0.15)
			tween.tween_property(d, "scale", Vector2.ONE, 0.15)
	tween.finished.connect(func():
		modal_backdrop.visible = false
		play_dialog.visible = false
		load_dialog.visible = false
		settings_dialog.visible = false
		if settings_confirm_dialog:
			settings_confirm_dialog.visible = false
		about_dialog.visible = false
		if is_inside_tree():
			if is_instance_valid(return_focus): return_focus.grab_focus()
			else: btn_play.grab_focus()
	)

func show_toast(text: String) -> void:
	if not toast_panel or not toast_label:
		return
	toast_label.text = NoirUI.clean_text(text)
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

	var is_cancel_key: bool = event.is_action_pressed("ui_cancel") and not event.is_echo()
	var is_load_key: bool = event.is_action_pressed("quick_load") and not event.is_echo()

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
