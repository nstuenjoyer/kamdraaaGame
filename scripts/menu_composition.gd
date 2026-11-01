extends Control

# Finishing light/shadow over the illustrated apartment. UI is drawn separately.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var scale_value: Vector2 = size / Vector2(1280, 720)
	draw_set_transform(Vector2.ZERO, 0.0, scale_value)
	for index: int in 64:
		var x: float = float(index) * 10.0
		var opacity: float = 0.27*(1.0-smoothstep(280.0,640.0,x))
		draw_rect(Rect2(x, 0, 10, 720), Color(0.02, 0.025, 0.03, opacity))
	draw_line(Vector2(80, 92), Vector2(114, 92), NoirUI.ACCENT, 2.0)
	draw_line(Vector2(80, 614), Vector2(410, 614), Color(0.55,0.55,0.50,0.20), 1.0)
