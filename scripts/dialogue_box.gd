extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var container: Control = $DialogueContainer
@onready var panel: PanelContainer = $DialogueContainer/Panel
@onready var speaker_label: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/HeaderBox/SpeakerLabel
@onready var paranoia_badge: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/HeaderBox/ParanoiaBadge
@onready var text_label: Control = $DialogueContainer/Panel/MarginContainer/VBoxContainer/TextLabel
@onready var paranoia_whisper: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/ParanoiaWhisper
@onready var continue_prompt: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/ContinuePrompt

var dialogue_lines: Array[Dictionary] = []
var current_line_index: int = -1
var is_active: bool = false
var is_typing: bool = false
var typewriter_tween: Tween
var badge_tween: Tween
var whisper_tween: Tween
var _auto_advance_tween: Tween

var _is_paranoia_active: bool = false
var _base_panel_offset_left: float = -380.0
var _base_panel_offset_right: float = 380.0
var _base_panel_offset_top: float = -175.0
var _base_panel_offset_bottom: float = -25.0

var panel_style: StyleBoxFlat
var _dialogue_paranoia_accum: float = 0.0

# Портреты персонажей в диалогах
var _tex_dasha_calm: Texture2D
var _tex_dasha_panic: Texture2D
var _tex_stranger: Texture2D
var _tex_clue: Texture2D

var _portrait_panel: PanelContainer = null
var _portrait_rect: TextureRect = null
var _portrait_style: StyleBoxFlat = null

# Журнал истории диалогов (Dialogue History / Backlog)
var dialogue_history: Array[Dictionary] = []
var _is_history_open: bool = false
var _history_root: Control = null
var _history_list: VBoxContainer = null
var _history_scroll: ScrollContainer = null
var _history_count_label: Label = null
var btn_history: Button = null

const PARANOIA_WHISPER_FALLBACKS: Array[String] = [
	"«...в висках пульсирует кровь... кто это?.. откуда они знают?..»",
	"«...каждое слово отдаётся тупой болью... это ловушка?..»",
	"«...голос чужой, искажённый помехами... никому не верь...»",
	"«...в полумраке кажется, будто тени шевелятся...»"
]

func _ready() -> void:
	if container:
		container.visible = false
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_portraits()
	_setup_panel_style()
	_setup_portrait_ui()
	_setup_history_ui()

func _setup_panel_style() -> void:
	if not panel:
		return
	_base_panel_offset_left = panel.offset_left
	_base_panel_offset_right = panel.offset_right
	_base_panel_offset_top = panel.offset_top
	_base_panel_offset_bottom = panel.offset_bottom

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not panel.gui_input.is_connected(_on_dialogue_gui_input):
		panel.gui_input.connect(_on_dialogue_gui_input)

	if container:
		if not container.gui_input.is_connected(_on_dialogue_gui_input):
			container.gui_input.connect(_on_dialogue_gui_input)

	var margin_c: Control = get_node_or_null("DialogueContainer/Panel/MarginContainer") as Control
	if margin_c:
		margin_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox_c: Control = get_node_or_null("DialogueContainer/Panel/MarginContainer/VBoxContainer") as Control
	if vbox_c:
		vbox_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_c: Control = get_node_or_null("DialogueContainer/Panel/MarginContainer/VBoxContainer/HeaderBox") as Control
	if header_c:
		header_c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if text_label:
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if speaker_label:
		speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if paranoia_badge:
		paranoia_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if paranoia_whisper:
		paranoia_whisper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if continue_prompt:
		continue_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.45, 0.65, 0.85)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.65)
	panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", panel_style)

func _on_dialogue_gui_input(event: InputEvent) -> void:
	if not is_active or _is_history_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		advance_dialogue()

func _setup_history_ui() -> void:
	# 1. Кнопка "История [H]" на шапке диалогового окна
	var header_box: HBoxContainer = (speaker_label.get_parent() as HBoxContainer) if speaker_label else (get_node_or_null("DialogueContainer/Panel/MarginContainer/VBoxContainer/HeaderBox") as HBoxContainer)
	if header_box:
		btn_history = Button.new()
		btn_history.text = "📜 История [H]"
		btn_history.custom_minimum_size = Vector2(98, 22)
		btn_history.add_theme_font_size_override("font_size", 10)
		btn_history.focus_mode = Control.FOCUS_NONE

		var btn_h_norm: StyleBoxFlat = StyleBoxFlat.new()
		btn_h_norm.bg_color = Color(0.1, 0.14, 0.22, 0.85)
		btn_h_norm.border_width_left = 1
		btn_h_norm.border_width_top = 1
		btn_h_norm.border_width_right = 1
		btn_h_norm.border_width_bottom = 1
		btn_h_norm.border_color = Color(0.25, 0.55, 0.75, 0.8)
		btn_h_norm.corner_radius_top_left = 4
		btn_h_norm.corner_radius_top_right = 4
		btn_h_norm.corner_radius_bottom_right = 4
		btn_h_norm.corner_radius_bottom_left = 4
		btn_history.add_theme_stylebox_override("normal", btn_h_norm)

		var btn_h_hover: StyleBoxFlat = StyleBoxFlat.new()
		btn_h_hover.bg_color = Color(0.16, 0.24, 0.36, 0.95)
		btn_h_hover.border_width_left = 1
		btn_h_hover.border_width_top = 1
		btn_h_hover.border_width_right = 1
		btn_h_hover.border_width_bottom = 1
		btn_h_hover.border_color = Color(0.1, 0.85, 1.0, 0.95)
		btn_h_hover.corner_radius_top_left = 4
		btn_h_hover.corner_radius_top_right = 4
		btn_h_hover.corner_radius_bottom_right = 4
		btn_h_hover.corner_radius_bottom_left = 4
		btn_history.add_theme_stylebox_override("hover", btn_h_hover)

		btn_history.pressed.connect(toggle_history)
		var s_mgr: Node = get_node_or_null("/root/SoundManager")
		btn_history.mouse_entered.connect(func():
			if s_mgr and s_mgr.has_method("play_hover"): s_mgr.play_hover()
		)
		btn_history.pressed.connect(func():
			if s_mgr and s_mgr.has_method("play_click"): s_mgr.play_click()
		)
		header_box.add_child(btn_history)

	# 2. Модальное окно журнала истории диалога
	_history_root = Control.new()
	_history_root.name = "HistoryDialogRoot"
	_history_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_root.visible = false
	add_child(_history_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_root.add_child(backdrop)

	var panel_c: PanelContainer = PanelContainer.new()
	panel_c.set_anchors_preset(Control.PRESET_CENTER)
	panel_c.custom_minimum_size = Vector2(760, 500)
	panel_c.offset_left = -380
	panel_c.offset_right = 380
	panel_c.offset_top = -250
	panel_c.offset_bottom = 250
	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.1, 0.16, 0.98)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.18, 0.65, 0.85, 0.85)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.shadow_color = Color(0, 0, 0, 0.7)
	p_style.shadow_size = 18
	panel_c.add_theme_stylebox_override("panel", p_style)
	_history_root.add_child(panel_c)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel_c.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header HBox
	var hbox_head: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox_head)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📜 ИСТОРИЯ ДИАЛОГА"
	title_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 16)
	hbox_head.add_child(title_lbl)

	_history_count_label = Label.new()
	_history_count_label.text = "[ 0 реплик ]"
	_history_count_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.8))
	_history_count_label.add_theme_font_size_override("font_size", 12)
	_history_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_head.add_child(_history_count_label)

	var btn_close: Button = Button.new()
	btn_close.text = "✕ Закрыть [Esc / H]"
	btn_close.custom_minimum_size = Vector2(140, 32)
	btn_close.pressed.connect(close_history)
	var s_mgr2: Node = get_node_or_null("/root/SoundManager")
	btn_close.mouse_entered.connect(func():
		if s_mgr2 and s_mgr2.has_method("play_hover"): s_mgr2.play_hover()
	)
	btn_close.pressed.connect(func():
		if s_mgr2 and s_mgr2.has_method("play_click"): s_mgr2.play_click()
	)
	hbox_head.add_child(btn_close)

	var div: ColorRect = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.2, 0.35, 0.5, 0.6)
	vbox.add_child(div)

	# Scroll Container
	_history_scroll = ScrollContainer.new()
	_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_history_scroll)

	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 10)
	_history_scroll.add_child(_history_list)

func _process(_delta: float) -> void:
	if is_active and _is_paranoia_active and panel:
		# Нервная дрожь и тремор диалогового окна, масштабирующиеся от пульса и паранойи Даши
		var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
		var p_level: float = paranoia_mgr.get_paranoia() if (paranoia_mgr and paranoia_mgr.has_method("get_paranoia")) else 30.0
		var jitter_factor: float = lerpf(0.8, 2.6, clampf(p_level / 100.0, 0.0, 1.0))
		var jx: float = randf_range(-1.6, 1.6) * jitter_factor
		var jy: float = randf_range(-1.1, 1.1) * jitter_factor
		panel.offset_left = _base_panel_offset_left + jx
		panel.offset_right = _base_panel_offset_right + jx
		panel.offset_top = _base_panel_offset_top + jy
		panel.offset_bottom = _base_panel_offset_bottom + jy

		if panel_style:
			var t: float = Time.get_ticks_msec() * 0.008
			var pulse: float = (sin(t) + 1.0) * 0.5
			var c1: Color = Color(1.0, 0.22, 0.35, 0.95)
			var c2: Color = Color(1.0, 0.65, 0.15, 0.95)
			panel_style.border_color = c1.lerp(c2, pulse)

func _reset_panel_position() -> void:
	if not panel:
		return
	panel.offset_left = _base_panel_offset_left
	panel.offset_right = _base_panel_offset_right
	panel.offset_top = _base_panel_offset_top
	panel.offset_bottom = _base_panel_offset_bottom

func start_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	dialogue_lines.clear()
	for item in lines:
		if item is Dictionary:
			dialogue_lines.append(item)
	if dialogue_lines.is_empty():
		return
	current_line_index = -1
	_dialogue_paranoia_accum = 0.0 # Сброс накопленной паранойи для нового разговора
	is_active = true
	if container:
		container.visible = true
		container.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_started.emit()
	_show_next_line()

func _show_next_line() -> void:
	if _auto_advance_tween and _auto_advance_tween.is_valid():
		_auto_advance_tween.kill()

	current_line_index += 1
	if current_line_index >= dialogue_lines.size():
		_close_dialogue()
		return

	if current_line_index > 0:
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_dialogue_advance"):
			sound_mgr.play_dialogue_advance()

	var current_data: Dictionary = dialogue_lines[current_line_index]
	var speaker: String = current_data.get("speaker", "")
	var raw_text: String = current_data.get("text", "")
	var color: Color = current_data.get("color", Color(1, 1, 1, 1))

	# Добавляем в историю диалогов
	dialogue_history.append(current_data)

	# Проверка эффекта паранойи
	var is_paranoia: bool = false
	if current_data.has("paranoia"):
		is_paranoia = bool(current_data["paranoia"])
	else:
		var sp_low: String = speaker.to_lower()
		is_paranoia = not ("даша" in sp_low or "система" in sp_low)

	_is_paranoia_active = is_paranoia

	speaker_label.text = speaker
	speaker_label.modulate = color

	# Обновление нуарного портрета персонажа
	_update_portrait(speaker, is_paranoia, current_data)

	if is_paranoia:
		if paranoia_badge:
			paranoia_badge.visible = true
			if badge_tween and badge_tween.is_valid():
				badge_tween.kill()
			badge_tween = create_tween().set_loops()
			badge_tween.tween_property(paranoia_badge, "modulate:a", 0.4, 0.35)
			badge_tween.tween_property(paranoia_badge, "modulate:a", 1.0, 0.35)

		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_paranoia_pulse"):
			sound_mgr.play_paranoia_pulse()

		# Мягкое и ограниченное повышение паранойи в диалоге (максимум +8% за весь разговор)
		var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
		if paranoia_mgr and paranoia_mgr.has_method("add_paranoia"):
			var remaining_allowance: float = maxf(0.0, 8.0 - _dialogue_paranoia_accum)
			var bump: float = minf(2.5, remaining_allowance)
			if bump > 0.05:
				_dialogue_paranoia_accum += bump
				paranoia_mgr.add_paranoia(bump, speaker)

		if paranoia_whisper:
			var whisper_text: String = current_data.get("paranoia_whisper", "")
			if whisper_text.is_empty():
				whisper_text = PARANOIA_WHISPER_FALLBACKS[randi() % PARANOIA_WHISPER_FALLBACKS.size()]
			paranoia_whisper.text = whisper_text
			paranoia_whisper.visible = true

			if whisper_tween and whisper_tween.is_valid():
				whisper_tween.kill()
			paranoia_whisper.modulate.a = 0.0
			whisper_tween = create_tween()
			whisper_tween.tween_property(paranoia_whisper, "modulate:a", 0.85, 0.4)

		if text_label is RichTextLabel:
			var formatted_text: String = "[shake rate=22.0 level=6 connected=0]" + raw_text + "[/shake]"
			text_label.text = formatted_text
		else:
			text_label.text = raw_text

	else:
		if paranoia_badge:
			paranoia_badge.visible = false
		if paranoia_whisper:
			paranoia_whisper.visible = false
		if badge_tween and badge_tween.is_valid():
			badge_tween.kill()
		if whisper_tween and whisper_tween.is_valid():
			whisper_tween.kill()

		if panel_style:
			panel_style.border_color = Color(0.2, 0.45, 0.65, 0.85)
		_reset_panel_position()

		text_label.text = raw_text

	text_label.visible_ratio = 0.0
	is_typing = true
	continue_prompt.modulate.a = 0.3

	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()

	# Скорость печати с учётом настроек игрока
	var base_speed: float = 0.024
	var settings_mgr: Node = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_method("get_typewriter_char_duration"):
		base_speed = settings_mgr.get_typewriter_char_duration()

	if base_speed <= 0.001:
		# Режим "Мгновенно"
		text_label.visible_ratio = 1.0
		_on_typing_completed()
	else:
		var speed_per_char: float = base_speed * (0.85 if is_paranoia else 1.0)
		var total_chars: int = raw_text.length()
		var duration: float = maxf(0.18, float(total_chars) * speed_per_char)
		typewriter_tween = create_tween()
		var last_tick_char: Array[int] = [0]
		typewriter_tween.tween_method(func(ratio: float):
			text_label.visible_ratio = ratio
			var curr_chars: int = int(ratio * float(total_chars))
			if curr_chars >= last_tick_char[0] + 3:
				last_tick_char[0] = curr_chars
				var sound_mgr: Node = get_node_or_null("/root/SoundManager")
				if sound_mgr and sound_mgr.has_method("play_typewriter_tick"):
					sound_mgr.play_typewriter_tick()
		, 0.0, 1.0, duration)
		typewriter_tween.finished.connect(_on_typing_completed)

func _on_typing_completed() -> void:
	is_typing = false
	text_label.visible_ratio = 1.0
	continue_prompt.modulate.a = 1.0

	# Проверяем авто-прокрутку реплик
	var settings_mgr: Node = get_node_or_null("/root/SettingsManager")
	if settings_mgr and bool(settings_mgr.get("auto_advance")):
		var delay: float = float(settings_mgr.get("auto_advance_delay"))
		if delay <= 0.5:
			delay = 1.5
		if _auto_advance_tween and _auto_advance_tween.is_valid():
			_auto_advance_tween.kill()
		_auto_advance_tween = create_tween()
		_auto_advance_tween.tween_interval(delay)
		_auto_advance_tween.finished.connect(func():
			if is_active and not is_typing and not _is_history_open:
				_show_next_line()
		)

func _finish_typing_instantly() -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	_on_typing_completed()

func toggle_history() -> void:
	if _is_history_open:
		close_history()
	else:
		open_history()

func open_history() -> void:
	if _is_history_open:
		return
	_is_history_open = true
	_populate_history_cards()
	if _history_root:
		_history_root.visible = true

	var s_mgr: Node = get_node_or_null("/root/SoundManager")
	if s_mgr and s_mgr.has_method("play_hover"):
		s_mgr.play_hover()

	# Авто-скролл к последней реплике
	await get_tree().process_frame
	if _history_scroll:
		var v_bar: VScrollBar = _history_scroll.get_v_scroll_bar()
		if v_bar:
			_history_scroll.scroll_vertical = int(v_bar.max_value)

func close_history() -> void:
	if not _is_history_open:
		return
	_is_history_open = false
	if _history_root:
		_history_root.visible = false
	var s_mgr: Node = get_node_or_null("/root/SoundManager")
	if s_mgr and s_mgr.has_method("play_click"):
		s_mgr.play_click()

func _populate_history_cards() -> void:
	if not _history_list:
		return
	for c in _history_list.get_children():
		c.queue_free()

	if _history_count_label:
		_history_count_label.text = "[ Реплик: %d ]" % dialogue_history.size()

	if dialogue_history.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "История разговоров пока пуста."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 0.7))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_history_list.add_child(empty_lbl)
		return

	for entry in dialogue_history:
		var card: PanelContainer = PanelContainer.new()
		var c_style: StyleBoxFlat = StyleBoxFlat.new()
		c_style.bg_color = Color(0.1, 0.13, 0.2, 0.8)
		c_style.border_width_left = 3
		var sp_color: Color = entry.get("color", Color(0.4, 0.8, 1.0))
		c_style.border_color = sp_color
		c_style.corner_radius_top_left = 4
		c_style.corner_radius_top_right = 4
		c_style.corner_radius_bottom_right = 4
		c_style.corner_radius_bottom_left = 4
		card.add_theme_stylebox_override("panel", c_style)

		var card_margin: MarginContainer = MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(card_margin)

		var card_vbox: VBoxContainer = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_margin.add_child(card_vbox)

		# Speaker Label
		var spk: Label = Label.new()
		spk.text = entry.get("speaker", "...")
		spk.add_theme_color_override("font_color", sp_color)
		spk.add_theme_font_size_override("font_size", 13)
		card_vbox.add_child(spk)

		# Text Label
		var txt: Label = Label.new()
		txt.text = entry.get("text", "")
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_font_size_override("font_size", 12)
		txt.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.95))
		card_vbox.add_child(txt)

		# Paranoia Whisper
		var whisper: String = entry.get("paranoia_whisper", "")
		if whisper != "":
			var wh_lbl: Label = Label.new()
			wh_lbl.text = "⚡ " + whisper
			wh_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wh_lbl.add_theme_font_size_override("font_size", 11)
			wh_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45, 0.85))
			card_vbox.add_child(wh_lbl)

		_history_list.add_child(card)

func cancel_dialogue() -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	if badge_tween and badge_tween.is_valid():
		badge_tween.kill()
	if whisper_tween and whisper_tween.is_valid():
		whisper_tween.kill()
	if _auto_advance_tween and _auto_advance_tween.is_valid():
		_auto_advance_tween.kill()

	_is_paranoia_active = false
	_reset_panel_position()
	if panel_style:
		panel_style.border_color = Color(0.2, 0.45, 0.65, 0.85)

	is_typing = false
	is_active = false
	dialogue_lines.clear()
	current_line_index = -1
	if container:
		container.visible = false
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_history()
	dialogue_finished.emit()

func _close_dialogue() -> void:
	if badge_tween and badge_tween.is_valid():
		badge_tween.kill()
	if whisper_tween and whisper_tween.is_valid():
		whisper_tween.kill()
	if _auto_advance_tween and _auto_advance_tween.is_valid():
		_auto_advance_tween.kill()

	_is_paranoia_active = false
	_reset_panel_position()
	if panel_style:
		panel_style.border_color = Color(0.2, 0.45, 0.65, 0.85)

	is_active = false
	if container:
		container.visible = false
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_history()
	dialogue_finished.emit()

func advance_dialogue() -> void:
	if not is_active or _is_history_open:
		return
	if _auto_advance_tween and _auto_advance_tween.is_valid():
		_auto_advance_tween.kill()

	if is_typing:
		# Первое нажатие при печати мгновенно раскрывает всю фразу
		_finish_typing_instantly()
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_dialogue_advance"):
			sound_mgr.play_dialogue_advance()
	else:
		# Повторное нажатие переходит к следующей реплике
		_show_next_line()

func _unhandled_input(event: InputEvent) -> void:
	# Открытие/закрытие журнала истории диалогов
	var is_wheel_up: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed)
	var is_key_h: bool = (event is InputEventKey and event.keycode == KEY_H and event.pressed and not event.is_echo())

	if _is_history_open:
		if (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo()) or is_key_h:
			get_viewport().set_input_as_handled()
			close_history()
		return

	if is_wheel_up or is_key_h:
		if is_active or not dialogue_history.is_empty():
			get_viewport().set_input_as_handled()
			open_history()
			return

	if not is_active:
		return

	var is_lmb: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	var is_space: bool = (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.is_echo())
	var is_enter: bool = (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER) and event.pressed and not event.is_echo())
	var is_interact_action: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.is_echo())

	if is_lmb or is_space or is_enter or is_interact_action:
		get_viewport().set_input_as_handled()
		advance_dialogue()

# =========================================================================
# Управление нуарными портретами персонажей
# =========================================================================

func _load_portraits() -> void:
	if ResourceLoader.exists("res://assets/portraits/dasha_calm.jpg"):
		_tex_dasha_calm = load("res://assets/portraits/dasha_calm.jpg")
	if ResourceLoader.exists("res://assets/portraits/dasha_panic.jpg"):
		_tex_dasha_panic = load("res://assets/portraits/dasha_panic.jpg")
	if ResourceLoader.exists("res://assets/portraits/stranger.jpg"):
		_tex_stranger = load("res://assets/portraits/stranger.jpg")
	if ResourceLoader.exists("res://assets/portraits/clue.jpg"):
		_tex_clue = load("res://assets/portraits/clue.jpg")

func _setup_portrait_ui() -> void:
	var margin_c: MarginContainer = get_node_or_null("DialogueContainer/Panel/MarginContainer") as MarginContainer
	var vbox_c: VBoxContainer = get_node_or_null("DialogueContainer/Panel/MarginContainer/VBoxContainer") as VBoxContainer
	if not margin_c or not vbox_c:
		return

	# Горизонтальный контейнер для портрета и текстового блока
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "DialogueContentHBox"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	margin_c.remove_child(vbox_c)
	margin_c.add_child(hbox)

	# Панель-рамка портрета в неонуарном стиле
	_portrait_panel = PanelContainer.new()
	_portrait_panel.name = "PortraitPanel"
	_portrait_panel.custom_minimum_size = Vector2(104, 104)
	_portrait_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_portrait_style = StyleBoxFlat.new()
	_portrait_style.bg_color = Color(0.04, 0.06, 0.1, 0.95)
	_portrait_style.border_width_left = 2
	_portrait_style.border_width_top = 2
	_portrait_style.border_width_right = 2
	_portrait_style.border_width_bottom = 2
	_portrait_style.border_color = Color(0.2, 0.55, 0.8, 0.85)
	_portrait_style.corner_radius_top_left = 6
	_portrait_style.corner_radius_top_right = 6
	_portrait_style.corner_radius_bottom_right = 6
	_portrait_style.corner_radius_bottom_left = 6
	_portrait_style.shadow_color = Color(0, 0, 0, 0.5)
	_portrait_style.shadow_size = 6
	_portrait_panel.add_theme_stylebox_override("panel", _portrait_style)

	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "PortraitRect"
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_panel.add_child(_portrait_rect)

	hbox.add_child(_portrait_panel)
	vbox_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_c)

func _update_portrait(speaker: String, is_paranoia: bool, _current_data: Dictionary) -> void:
	if not _portrait_rect or not _portrait_panel:
		return

	var sp_low: String = speaker.to_lower()
	var tex: Texture2D = null
	var border_col: Color = Color(0.25, 0.55, 0.85, 0.85)

	var paranoia_mgr: Node = get_node_or_null("/root/ParanoiaManager")
	var is_high_paranoia: bool = (paranoia_mgr and paranoia_mgr.has_method("get_paranoia") and paranoia_mgr.get_paranoia() >= 55.0)

	if "даша" in sp_low:
		if is_paranoia or is_high_paranoia:
			tex = _tex_dasha_panic
			border_col = Color(1.0, 0.3, 0.42, 0.95)
		else:
			tex = _tex_dasha_calm
			border_col = Color(0.35, 0.82, 0.95, 0.85)
	elif "телефон" in sp_low or "незнакомец" in sp_low or "голос" in sp_low or "связной" in sp_low:
		tex = _tex_stranger
		border_col = Color(0.95, 0.45, 0.35, 0.95)
	elif "система" in sp_low:
		tex = null
	else:
		tex = _tex_clue
		border_col = Color(0.85, 0.75, 0.4, 0.85)

	if tex:
		_portrait_panel.visible = true
		_portrait_rect.texture = tex
		if _portrait_style:
			_portrait_style.border_color = border_col

		# Деликатная кинетическая реакция при смене говорящего
		var pt_tween: Tween = create_tween()
		_portrait_rect.pivot_offset = _portrait_rect.size * 0.5
		pt_tween.tween_property(_portrait_rect, "scale", Vector2(1.04, 1.04), 0.07)
		pt_tween.tween_property(_portrait_rect, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
	else:
		_portrait_panel.visible = false
