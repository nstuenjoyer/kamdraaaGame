extends Area2D

# Ссылки на связанные узлы сцены
@export var door_to_open: StaticBody2D
@export var dialogue_box: CanvasLayer
@export var player: CharacterBody2D

@onready var phone_sprite: CanvasItem = get_node_or_null("PhoneBody") as CanvasItem
@onready var phone_label: Label = get_node_or_null("PhoneLabel") as Label

var is_player_nearby: bool = false
var is_phone_answered: bool = false
var ring_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_start_ringing_animation()
	if not is_phone_answered:
		var sound_mgr: Node = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("start_phone_ringing"):
			sound_mgr.start_phone_ringing()

func _exit_tree() -> void:
	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("stop_phone_ringing"):
		sound_mgr.stop_phone_ringing()

func _start_ringing_animation() -> void:
	if not phone_sprite:
		return
	if ring_tween and ring_tween.is_valid():
		ring_tween.kill()
	ring_tween = create_tween().set_loops()
	ring_tween.tween_property(phone_sprite, "modulate", Color(1.5, 1.3, 0.4, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
	ring_tween.tween_property(phone_sprite, "modulate", Color(0.9, 0.8, 0.7, 1.0), 0.35).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if is_player_nearby and not is_phone_answered:
		var pressed_interact: bool = (InputMap.has_action("interact") and Input.is_action_just_pressed("interact")) \
			or Input.is_action_just_pressed("ui_accept") \
			or Input.is_key_pressed(KEY_E)
		if pressed_interact:
			answer_phone()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = true
		if not is_phone_answered:
			if phone_label:
				phone_label.text = "☎ Взять трубку [E / Пробел]"

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = false
		if not is_phone_answered and phone_label:
			phone_label.text = "☎ Звонок..."

func set_phone_state(answered: bool) -> void:
	is_phone_answered = answered
	if ring_tween and ring_tween.is_valid():
		ring_tween.kill()

	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if target_dialogue and target_dialogue.has_signal("dialogue_finished"):
		if target_dialogue.dialogue_finished.is_connected(_on_dialogue_finished):
			target_dialogue.dialogue_finished.disconnect(_on_dialogue_finished)

	var p: Node2D = player if player else get_node_or_null("../Player") as Node2D
	if p:
		is_player_nearby = (global_position.distance_to(p.global_position) <= 65.0)

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if answered:
		if sound_mgr and sound_mgr.has_method("stop_phone_ringing"):
			sound_mgr.stop_phone_ringing()
		if phone_sprite:
			phone_sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if phone_label:
			phone_label.text = "☎ Разговор окончен"
			phone_label.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		if sound_mgr and sound_mgr.has_method("start_phone_ringing"):
			sound_mgr.start_phone_ringing()
		if phone_label:
			phone_label.text = "☎ Взять трубку [E / Пробел]" if is_player_nearby else "☎ Звонок..."
			phone_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_start_ringing_animation()

func answer_phone() -> void:
	if is_phone_answered:
		return
	is_phone_answered = true

	# Останавливаем звонок и пульсацию
	if ring_tween and ring_tween.is_valid():
		ring_tween.kill()

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		if sound_mgr.has_method("stop_phone_ringing"):
			sound_mgr.stop_phone_ringing()
		if sound_mgr.has_method("play_phone_pickup"):
			sound_mgr.play_phone_pickup()

	if phone_sprite:
		phone_sprite.modulate = Color(1.0, 0.95, 0.7, 1.0)
	if phone_label:
		phone_label.text = "☎ Идёт разговор..."
		phone_label.modulate = Color(0.4, 0.85, 1.0, 0.95)

	# Находим игрока и UI диалога, если не назначены через инспектор
	var target_player: CharacterBody2D = player if player else get_node_or_null("../Player") as CharacterBody2D
	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer

	if target_player and target_player.has_method("set_control_locked"):
		target_player.set_control_locked(true)

	var dialogue_lines: Array[Dictionary] = [
		{
			"speaker": "📞 Старый телефон",
			"text": "ДЗЫЫЫЫНЬ... ДЗЫЫЫЫНЬ... ЩЁЛК.",
			"color": Color(0.95, 0.8, 0.4),
			"paranoia": true,
			"paranoia_whisper": "«...в ушах звенит пронзительный ультразвук... череп готов расколоться...»"
		},
		{
			"speaker": "Даша",
			"text": "Алло?.. Кто это? Голова... раскалывается, будто по ней проехал поезд.",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "Хриплый голос",
			"text": "Камарина, ты жива вообще?! Мы тебя с самого утра ищем! Ну ты вчера и устроила дебош...",
			"color": Color(1.0, 0.6, 0.2),
			"paranoia": true,
			"paranoia_whisper": "«...откуда он знает твоё имя?.. это засада?.. сердце выпрыгивает из груди...»"
		},
		{
			"speaker": "Даша",
			"text": "Дебош?.. Где я вообще? Что это за квартира?!",
			"color": Color(0.5, 0.75, 1.0),
			"paranoia": false
		},
		{
			"speaker": "Хриплый голос",
			"text": "В конспиративной берлоге. Меньше надо было мешать текилу с абсентом! Сматывайся оттуда живо, пока хвост не сел. Дверь я тебе дистанционно разблокировал. Ждём снизу!",
			"color": Color(1.0, 0.6, 0.2),
			"paranoia": true,
			"paranoia_whisper": "«...хвост?.. наёмники тайного синдиката?.. в коридоре шаги?.. нужно бежать...»"
		},
		{
			"speaker": "📞 Старый телефон",
			"text": "ЩЁЛК... Короткие гудки: пип... пип... пип...",
			"color": Color(0.8, 0.8, 0.8),
			"paranoia": true,
			"paranoia_whisper": "«...в трубке повисла мертвенная тишина... он оборвал связь...»"
		},
		{
			"speaker": "🚪 Система",
			"text": "Электронный замок щёлкнул. Дверь разблокирована!",
			"color": Color(0.3, 1.0, 0.5),
			"paranoia": false
		}
	]

	if target_dialogue and target_dialogue.has_method("start_dialogue"):
		if not target_dialogue.dialogue_finished.is_connected(_on_dialogue_finished):
			target_dialogue.dialogue_finished.connect(_on_dialogue_finished)
		target_dialogue.start_dialogue(dialogue_lines)
	else:
		_on_dialogue_finished()

func _on_dialogue_finished() -> void:
	var target_dialogue: CanvasLayer = dialogue_box if dialogue_box else get_node_or_null("../UI") as CanvasLayer
	if target_dialogue and target_dialogue.has_signal("dialogue_finished"):
		if target_dialogue.dialogue_finished.is_connected(_on_dialogue_finished):
			target_dialogue.dialogue_finished.disconnect(_on_dialogue_finished)

	var target_player: CharacterBody2D = player if player else get_node_or_null("../Player") as CharacterBody2D
	if target_player and target_player.has_method("set_control_locked"):
		target_player.set_control_locked(false)

	# Разговор завершён — обновляем визуальное состояние телефона
	if phone_sprite:
		phone_sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
	if phone_label:
		phone_label.text = "☎ Разговор окончен"
		phone_label.modulate = Color(0.6, 0.6, 0.6, 0.8)

	# Регистрируем улики звонка и разблокированной двери
	var clue_mgr: Node = get_node_or_null("/root/ClueManager")
	if clue_mgr and clue_mgr.has_method("discover_clue"):
		clue_mgr.discover_clue("phone")
		clue_mgr.discover_clue("door")

	open_door()

func open_door() -> void:
	var target_door: StaticBody2D = door_to_open if door_to_open else get_node_or_null("../Door") as StaticBody2D
	if target_door:
		if target_door.has_method("open"):
			target_door.open()
		else:
			var collision: Node = target_door.get_node_or_null("CollisionPolygon2D")
			if collision:
				collision.set_deferred("disabled", true)
			target_door.modulate.a = 0.25
			print("[СИСТЕМА]: Дверь открыта!")
			
		var save_mgr: Node = get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.has_method("auto_save"):
			save_mgr.auto_save("Электрозамок двери разблокирован")
	else:
		print("[ВНИМАНИЕ]: Узел двери не найден!")

