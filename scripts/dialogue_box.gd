extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var panel: PanelContainer = $DialogueContainer/Panel
@onready var speaker_label: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/TextLabel
@onready var continue_prompt: Label = $DialogueContainer/Panel/MarginContainer/VBoxContainer/ContinuePrompt
@onready var container: Control = $DialogueContainer

var dialogue_lines: Array[Dictionary] = []
var current_line_index: int = -1
var is_active: bool = false
var is_typing: bool = false
var typewriter_tween: Tween

func _ready() -> void:
	container.visible = false

func start_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		return
	dialogue_lines = lines
	current_line_index = -1
	is_active = true
	container.visible = true
	dialogue_started.emit()
	_show_next_line()

func _show_next_line() -> void:
	current_line_index += 1
	if current_line_index >= dialogue_lines.size():
		_close_dialogue()
		return

	var current_data: Dictionary = dialogue_lines[current_line_index]
	var speaker: String = current_data.get("speaker", "")
	var text: String = current_data.get("text", "")
	var color: Color = current_data.get("color", Color(1, 1, 1, 1))

	speaker_label.text = speaker
	speaker_label.modulate = color
	text_label.text = text
	text_label.visible_ratio = 0.0
	is_typing = true
	continue_prompt.modulate.a = 0.3

	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()

	# Скорость печати: ~35 символов в секунду
	var duration: float = maxf(0.3, float(text.length()) * 0.025)
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	typewriter_tween.finished.connect(_on_typing_completed)

func _on_typing_completed() -> void:
	is_typing = false
	text_label.visible_ratio = 1.0
	continue_prompt.modulate.a = 1.0

func _finish_typing_instantly() -> void:
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()
	_on_typing_completed()

func _close_dialogue() -> void:
	is_active = false
	container.visible = false
	dialogue_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	var is_lmb: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	var is_space: bool = (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.is_echo())
	var is_enter: bool = (event is InputEventKey and event.keycode == KEY_ENTER and event.pressed and not event.is_echo())

	if is_lmb or is_space or is_enter:
		get_viewport().set_input_as_handled()
		if is_typing:
			# Первое нажатие при печати мгновенно раскрывает всю фразу
			_finish_typing_instantly()
		else:
			# Повторное нажатие переходит к следующей реплике
			_show_next_line()
