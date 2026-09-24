extends StaticBody2D

# Скрипт двери с электрозамком
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var door_panel: Polygon2D = $DoorPanel
@onready var door_label: Label = $DoorLabel
@onready var lock_led: Polygon2D = get_node_or_null("LockLED") as Polygon2D

var is_opened: bool = false

func _ready() -> void:
	if door_label:
		door_label.text = "Заперто"
		door_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if door_panel:
		door_panel.color = Color(0.48, 0.22, 0.16, 1.0)
	if lock_led:
		lock_led.color = Color(1.0, 0.2, 0.2, 1.0)

func set_state(opened: bool) -> void:
	if opened:
		open()
	else:
		close()

func open() -> void:
	if is_opened:
		return
	is_opened = true

	# Отключаем физическую коллизию для свободного прохода
	if collision:
		collision.set_deferred("disabled", true)

	# Обновляем визуальный статус
	if door_label:
		door_label.text = "Открыто"
		door_label.modulate = Color(0.3, 1.0, 0.4, 1.0)
	if lock_led:
		lock_led.color = Color(0.2, 1.0, 0.4, 1.0)

	# Анимация открытия: полупрозрачность дверного полотна
	var tween: Tween = create_tween().set_parallel(true)
	if door_panel:
		tween.tween_property(door_panel, "color", Color(0.2, 0.5, 0.3, 0.4), 0.5)
		tween.tween_property(door_panel, "modulate:a", 0.3, 0.5)
	var door_side: CanvasItem = get_node_or_null("DoorSide") as CanvasItem
	if door_side:
		tween.tween_property(door_side, "modulate:a", 0.3, 0.5)

	print("🚪 [ДВЕРЬ]: Электрозамок открыт! Проход свободен.")

func close() -> void:
	is_opened = false
	if collision:
		collision.set_deferred("disabled", false)
	if door_label:
		door_label.text = "Заперто"
		door_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if lock_led:
		lock_led.color = Color(1.0, 0.2, 0.2, 1.0)
	if door_panel:
		door_panel.color = Color(0.48, 0.22, 0.16, 1.0)
		door_panel.modulate.a = 1.0
	var door_side: CanvasItem = get_node_or_null("DoorSide") as CanvasItem
	if door_side:
		door_side.modulate.a = 1.0
	print("🚪 [ДВЕРЬ]: Электрозамок заблокирован.")
