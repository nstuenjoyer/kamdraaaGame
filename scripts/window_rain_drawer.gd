class_name WindowRainDrawer
extends Node2D

# WindowRainDrawer — Отрисовка капель и струек дождя на изометрическом стекле окна

var _droplets: Array = []

func set_droplets(drops: Array) -> void:
	_droplets = drops
	queue_redraw()

func _draw() -> void:
	if _droplets.is_empty():
		return

	# Направление струйки (дождь стекает вниз с легким смещением по ветру)
	var slant: Vector2 = Vector2(1.2, 7.5).normalized()

	for drop in _droplets:
		var u: float = drop.get("u", 0.5)
		var v: float = drop.get("v", 0.5)
		var length: float = drop.get("length", 6.0)
		var alpha: float = drop.get("alpha", 0.5)

		# Рассчитываем координаты на изометрическом окне:
		# x от -30 до +30
		var x: float = lerpf(-30.0, 30.0, u)
		# Верхняя и нижняя граница стекла для данного x:
		var y_top: float = lerpf(-62.0, -91.0, u)
		var y_bottom: float = lerpf(13.0, -14.0, u)
		var y: float = lerpf(y_top, y_bottom, v)

		var start_pos: Vector2 = Vector2(x, y)
		var end_pos: Vector2 = start_pos + slant * length

		# Мягкий неоновый отблеск капли
		var drop_color: Color = Color(0.68, 0.82, 0.98, alpha * 0.75)
		draw_line(start_pos, end_pos, drop_color, 1.2, true)

		# Маленькая точка-капля в начале струйки
		draw_circle(start_pos, 0.9, Color(0.85, 0.92, 1.0, alpha * 0.9))
