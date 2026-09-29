extends StaticBody2D

# Скрипт двери с электрозамком
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var door_panel: Polygon2D = $DoorPanel
@onready var door_label: Label = $DoorLabel
@onready var lock_led: Polygon2D = get_node_or_null("LockLED") as Polygon2D
@onready var lock_light: PointLight2D = get_node_or_null("DoorLockLight") as PointLight2D
@onready var door_occluder: LightOccluder2D = get_node_or_null("DoorOccluder") as LightOccluder2D

var is_opened: bool = false
var door_tween: Tween

func _ready() -> void:
	if door_label:
		door_label.text = "Заперто"
		door_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if door_panel:
		door_panel.color = Color(0.48, 0.22, 0.16, 1.0)
	if lock_led:
		lock_led.color = Color(1.0, 0.2, 0.2, 1.0)
	if lock_light:
		lock_light.color = Color(1.0, 0.25, 0.2, 1.0)
	if door_occluder:
		door_occluder.visible = true

func set_state(opened: bool) -> void:
	if opened:
		open()
	else:
		close()

func open() -> void:
	if is_opened:
		return
	is_opened = true

	if door_tween and door_tween.is_valid():
		door_tween.kill()

	# Отключаем физическую коллизию для свободного прохода
	if collision:
		collision.set_deferred("disabled", true)

	var sound_mgr: Node = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_door_unlock"):
		sound_mgr.play_door_unlock()

	# Обновляем визуальный статус
	if door_label:
		door_label.visible = false
	if lock_led:
		lock_led.color = Color(0.2, 1.0, 0.4, 1.0)
	if lock_light:
		lock_light.color = Color(0.2, 1.0, 0.4, 1.0)
	if door_occluder:
		door_occluder.visible = false

	# Анимация распахивания створки: дверь распахивается вдоль стены коридора
	door_tween = create_tween().set_parallel(true)
	if door_panel:
		door_panel.modulate.a = 1.0
		door_panel.color = Color(0.45, 0.22, 0.15, 1.0)
		door_tween.tween_method(_set_door_swing, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var door_side: CanvasItem = get_node_or_null("DoorSide") as CanvasItem
	if door_side:
		door_tween.tween_property(door_side, "modulate:a", 0.0, 0.2)

	print("🚪 [ДВЕРЬ]: Электрозамок открыт! Створка распахнута вдоль стены.")

func close() -> void:
	is_opened = false
	if door_tween and door_tween.is_valid():
		door_tween.kill()

	if collision:
		collision.set_deferred("disabled", false)
	if door_label:
		door_label.text = "Заперто"
		door_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		door_label.visible = true
	if lock_led:
		lock_led.color = Color(1.0, 0.2, 0.2, 1.0)
	if lock_light:
		lock_light.color = Color(1.0, 0.25, 0.2, 1.0)
	if door_occluder:
		door_occluder.visible = true
	if door_panel:
		door_panel.modulate.a = 1.0
		door_panel.color = Color(0.48, 0.22, 0.16, 1.0)
		door_tween = create_tween().set_parallel(true)
		door_tween.tween_method(_set_door_swing, 1.0, 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var door_side: CanvasItem = get_node_or_null("DoorSide") as CanvasItem
	if door_side:
		door_side.modulate.a = 1.0
	print("🚪 [ДВЕРЬ]: Электрозамок заблокирован.")

func _set_door_swing(t: float) -> void:
	if not door_panel:
		return
	# Интерполяция положения створки: от закрытого (80, -40) к распахнутому вдоль стены коридора (60, 30)
	var tip_base: Vector2 = Vector2(80.0, -40.0).lerp(Vector2(60.0, 30.0), t)
	var tip_top: Vector2 = tip_base + Vector2(0.0, -65.0)
	door_panel.polygon = PackedVector2Array([
		Vector2(0, 0),
		tip_base,
		tip_top,
		Vector2(0, -65)
	])
