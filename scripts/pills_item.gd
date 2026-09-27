extends Area2D

# Интерактивный предмет: Блистер с успокоительными таблетками (PillsItem)
# Подбирается в инвентарь Даши для последующего использования

@export var prompt_title: String = "Успокоительное"
@export var dialogue_box: CanvasLayer
@export var player: CharacterBody2D

@onready var label: Label = get_node_or_null("PromptLabel") as Label
@onready var visual_root: CanvasItem = get_node_or_null("VisualRoot") as CanvasItem

var is_player_nearby: bool = false
var _pulse_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()
	_start_subtle_glow()

func _start_subtle_glow() -> void:
	if not visual_root:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(visual_root, "modulate", Color(1.2, 1.3, 1.4, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(visual_root, "modulate", Color(0.85, 0.9, 1.0, 0.9), 1.2).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if is_player_nearby:
		var pressed_interact: bool = (InputMap.has_action("interact") and Input.is_action_just_pressed("interact")) \
			or Input.is_action_just_pressed("ui_accept") \
			or Input.is_key_pressed(KEY_E)
		if pressed_interact:
			pick_up_pills()

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
		label.text = "💊 Взять %s [E]" % prompt_title
		label.modulate = Color(0.4, 0.95, 1.0, 1.0)
	else:
		label.visible = true
		label.text = "💊 %s" % prompt_title
		label.modulate = Color(0.65, 0.75, 0.85, 0.7)

func pick_up_pills() -> void:
	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if target_dialogue and "is_active" in target_dialogue and target_dialogue.is_active:
		return

	# Добавляем таблетки в инвентарь (3 дозы)
	var inv_mgr: Node = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		inv_mgr.add_item(
			"pills",
			"Седативные таблетки",
			3,
			"💊",
			"Блистер сильных успокоительных таблеток. Снимает приступы похмельной паранойи и тахикардии (-40% стресса). Можно принимать в любой момент через инвентарь [ I ].",
			true
		)

	# Запускаем диалог
	if target_dialogue and target_dialogue.has_method("start_dialogue"):
		var lines: Array[Dictionary] = [
			{
				"speaker": "Даша",
				"text": "Седативные таблетки... Заберу блистер с собой в карман пальто — пригодятся, если накроет новый приступ паники (клавиша [ I ]).",
				"color": Color(0.5, 0.8, 1.0),
				"paranoia": false
			}
		]
		target_dialogue.start_dialogue(lines)

	queue_free()
