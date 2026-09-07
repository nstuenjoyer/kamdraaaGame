extends Area2D

# Ссылка на узел двери, которую нужно открыть.
@export var door_to_open: StaticBody2D

# Находится ли Даша рядом с телефоном
var is_player_nearby: bool = false

# Был ли звонок уже принят
var is_phone_answered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if is_player_nearby and not is_phone_answered:
		var pressed_e: bool = (InputMap.has_action("interact") and Input.is_action_just_pressed("interact")) or Input.is_key_pressed(KEY_E)
		if pressed_e:
			answer_phone()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = true
		if not is_phone_answered:
			print(">>> [ПОДСКАЗКА]: Нажмите 'E', чтобы поднять трубку телефона.")

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = false

func answer_phone() -> void:
	is_phone_answered = true
	
	print("\n=======================================================")
	print("📞 [ЗВОНОК ТЕЛЕФОНА] ДЗЫЫЫЫНЬ... ДЗЫЫЫЫНЬ...")
	print("Даша поднимает тяжёлую трубку...")
	print("-------------------------------------------------------")
	print("Голос в трубке:")
	print("  — 'Камарина, алло?! Ты жива вообще?!")
	print("     Мы тебя с самого утра ищем! Ну ты вчера и устроила разнос...'")
	print("Даша:")
	print("  — 'Голова... раскалывается. Где я? Что вообще было вчера?!'")
	print("Голос в трубке:")
	print("  — 'Ха-ха, меньше пить надо было! В общем, выбирайся из квартиры,")
	print("     дверь я тебе дистанционно разблокировал. Ждём тебя снизу!'")
	print("-------------------------------------------------------")
	print("ЩЁЛК... Короткие гудки: пип... пип... пип...")
	print("🚪 [ДВЕРЬ]: Замок щёлкнул и дверь распахнулась!")
	print("=======================================================\n")
	
	open_door()

func open_door() -> void:
	var target_door: StaticBody2D = door_to_open if door_to_open else get_node_or_null("../Door")
	if target_door:
		if target_door.has_method("open"):
			target_door.open()
		else:
			var collision: Node = target_door.get_node_or_null("CollisionShape2D")
			if not collision:
				collision = target_door.get_node_or_null("CollisionPolygon2D")
			if collision:
				collision.set_deferred("disabled", true)
			target_door.modulate.a = 0.25
			print("[СИСТЕМА]: Дверь открыта!")
	else:
		print("[ВНИМАНИЕ]: Узел двери не найден!")
