extends StaticBody2D

# Простой и надежный скрипт изометрической двери
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var door_panel: Polygon2D = $DoorPanel
@onready var door_label: Label = $DoorLabel

var is_opened: bool = false

func _ready() -> void:
	if door_label:
		door_label.text = "Заперто"
		door_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if door_panel:
		door_panel.color = Color(0.55, 0.25, 0.15, 1.0)

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

	# Анимация открытия: полупрозрачность дверного полотна
	var tween: Tween = create_tween().set_parallel(true)
	if door_panel:
		tween.tween_property(door_panel, "color", Color(0.3, 0.8, 0.4, 0.4), 0.5)
		tween.tween_property(door_panel, "modulate:a", 0.3, 0.5)
	var door_side: CanvasItem = get_node_or_null("DoorSide") as CanvasItem
	if door_side:
		tween.tween_property(door_side, "modulate:a", 0.3, 0.5)

	print("🚪 [ДВЕРЬ]: Проход разблокирован! Коллизия отключена.")
