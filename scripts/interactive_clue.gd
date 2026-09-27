extends Area2D

# Универсальный скрипт интерактивного объекта / улики расследования
# Поддерживает подсветку, всплывающий запрос [E], диалог осмотра и регистрацию в ClueManager

@export var clue_id: String = "receipt"
@export var prompt_title: String = "Чек из бара"
@export var sound_method: String = "play_paper_rustle"
@export var dialogue_box: CanvasLayer
@export var player: CharacterBody2D

@onready var label: Label = get_node_or_null("PromptLabel") as Label
@onready var visual_root: CanvasItem = get_node_or_null("VisualRoot") as CanvasItem

var is_player_nearby: bool = false
var has_been_inspected: bool = false
var pulse_tween: Tween

# Диалоговые реплики для каждой улики
var _clue_dialogues: Dictionary = {
	"receipt": [
		{
			"speaker": "Даша",
			"text": "Под ногами валяется измятый кассовый чек из бара... Хм, что тут?",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "🧾 Кассовый чек",
			"text": "Бар «Неоновый туман». 03:42 ночи.\n• 3x Текила Сауэр\n• 2x Абсент Зелёная Фея\n• Штраф за бой посуды\nИтого: 8 400 ₽ (Оплачено картой)",
			"color": Color(0.95, 0.88, 0.6),
			"paranoia": false
		},
		{
			"speaker": "Даша",
			"text": "Ого... Судя по счёту, дебош действительно удался на славу. Но постойте...",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "🧾 Обратная сторона",
			"text": "На обратной стороне чека торопливо выведено красной пастой:\n«Не доверяй тому, кто позвонит первым...»",
			"color": Color(1.0, 0.35, 0.4),
			"paranoia": true,
			"paranoia_whisper": "«...чужой нервный почерк... чернила ещё не высохли... тебя хотели спасти?..»"
		},
		{
			"speaker": "Даша",
			"text": "«Не доверяй тому, кто позвонит первым»?! Кто написал это? И кто должен позвонить?!",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		}
	],
	"mirror": [
		{
			"speaker": "Даша",
			"text": "Настенное зеркало в холодной металлической раме. Поперёк мутного стекла что-то нацарапано...",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "💄 Надпись на зеркале",
			"text": "«КОНСПИРАТИВНАЯ КВАРТИРА №4. ВЫХОД ЧЕРЕЗ ДВЕРЬ НА ЮГЕ».",
			"color": Color(1.0, 0.25, 0.4),
			"paranoia": true,
			"paranoia_whisper": "«...в отражении зеркала позади тебя сгущаются тени... ты здесь не одна...»"
		},
		{
			"speaker": "Даша",
			"text": "След жирной рубиновой помады. Я никогда не крашу губы красным... В этой комнате была другая женщина.",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		}
	],
	"bottle": [
		{
			"speaker": "Даша",
			"text": "Осколки разбитой бутылки из тёмно-зелёного стекла. Острый травяной запах спирта и полыни...",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "Даша",
			"text": "Тот самый абсент из ночного чека. Но в луже на ковре...",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "Даша",
			"text": "Свежий отпечаток тяжёлого армейского берца 44-го размера. Сюда заходил мужчина.",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": true,
			"paranoia_whisper": "«...он шёл к тумбочке... его следы обрываются у входной двери...»"
		}
	]
}

func _ready() -> void:
	add_to_group("interactive_clues")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_pulse_animation()
	_update_label()

func _start_pulse_animation() -> void:
	if not visual_root:
		return
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(visual_root, "modulate", Color(1.2, 1.15, 0.9, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(visual_root, "modulate", Color(0.85, 0.85, 0.85, 0.95), 0.8).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby:
		return

	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if target_dialogue and "is_active" in target_dialogue and target_dialogue.is_active:
		return

	var is_interact: bool = event.is_action_pressed("interact") or (
		event is InputEventKey and event.pressed and not event.is_echo() and (
			event.keycode == KEY_E or event.keycode == KEY_SPACE
		)
	)
	if not is_interact:
		return

	# Если игрок находится в зоне действия нескольких улик, активируется строго ближайшая
	var target_player: CharacterBody2D = player if player else get_node_or_null("../Player") as CharacterBody2D
	if target_player:
		var my_col: CollisionShape2D = get_node_or_null("TriggerCollision") as CollisionShape2D
		var my_pos: Vector2 = my_col.global_position if my_col else global_position
		var my_dist: float = my_pos.distance_to(target_player.global_position)

		var tree: SceneTree = get_tree()
		if tree:
			var all_clues: Array[Node] = tree.get_nodes_in_group("interactive_clues")
			for other in all_clues:
				if other != self and other is Area2D and "is_player_nearby" in other and other.is_player_nearby:
					var other_col: CollisionShape2D = other.get_node_or_null("TriggerCollision") as CollisionShape2D
					var other_pos: Vector2 = other_col.global_position if other_col else other.global_position
					var other_dist: float = other_pos.distance_to(target_player.global_position)
					if other_dist < my_dist:
						return # Другая улика расположена ближе к Даше, уступаем вызов ей

	get_viewport().set_input_as_handled()
	interact()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = true
		_update_label()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = false
		_update_label()

func _update_label() -> void:
	if not label:
		return
	if is_player_nearby:
		label.visible = true
		label.text = "%s [E]" % prompt_title
		label.modulate = Color(1.0, 0.95, 0.5, 1.0)
	else:
		label.visible = true
		label.text = prompt_title
		label.modulate = Color(0.75, 0.8, 0.88, 0.75)

func interact() -> void:
	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if not target_dialogue or not target_dialogue.has_method("start_dialogue"):
		_on_inspection_finished()
		return

	if "is_active" in target_dialogue and target_dialogue.is_active:
		return

	# Звук взаимодействия
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method(sound_method):
		sound_mgr.call(sound_method)
	elif sound_mgr and sound_mgr.has_method("play_interact"):
		sound_mgr.play_interact()

	# Блокируем управление игрока
	var target_player: CharacterBody2D = player if player else get_node_or_null("../Player") as CharacterBody2D
	if target_player and target_player.has_method("set_control_locked"):
		target_player.set_control_locked(true)

	# Подключаем сигнал завершения диалога ДЛЯ ЛЮБОГО ТИПА ОСМОТРА
	if not target_dialogue.dialogue_finished.is_connected(_on_inspection_finished):
		target_dialogue.dialogue_finished.connect(_on_inspection_finished)

	# Отправляем реплики
	var raw_lines: Array = _clue_dialogues.get(clue_id, [])
	var lines: Array[Dictionary] = []
	for item in raw_lines:
		if item is Dictionary:
			lines.append(item)

	if lines.is_empty():
		_on_inspection_finished()
		return

	if has_been_inspected:
		# При повторном осмотре даём краткую реплику Даши
		var short_lines: Array[Dictionary] = [
			{
				"speaker": "Даша",
				"text": "Я уже осмотрела это (%s). Нужно двигаться дальше." % prompt_title,
				"color": Color(0.5, 0.75, 1.0),
				"paranoia": false
			}
		]
		target_dialogue.start_dialogue(short_lines)
	else:
		target_dialogue.start_dialogue(lines)

func _on_inspection_finished() -> void:
	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if target_dialogue and target_dialogue.has_signal("dialogue_finished"):
		if target_dialogue.dialogue_finished.is_connected(_on_inspection_finished):
			target_dialogue.dialogue_finished.disconnect(_on_inspection_finished)

	var target_player: CharacterBody2D = player if player else get_node_or_null("../Player") as CharacterBody2D
	if target_player and target_player.has_method("set_control_locked"):
		target_player.set_control_locked(false)

	has_been_inspected = true

	# Регистрируем улику в ClueManager
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if clue_mgr and clue_mgr.has_method("discover_clue"):
		clue_mgr.discover_clue(clue_id)
