extends Control

var floor_index: int = 1
var host: Node

func _draw() -> void:
	var offset: Vector2 = Vector2(size.x * 0.5, 105)
	var scale_factor: float = minf(size.x / 33.0, size.y / 24.0)
	var font: Font = ThemeDB.fallback_font
	for id: String in ApartmentLayout3D.ROOMS:
		var row: Array = ApartmentLayout3D.ROOMS[id]
		if int(row[0]) != floor_index: continue
		var r: Rect2 = row[1]
		var screen: Rect2 = Rect2(offset + r.position * scale_factor, r.size * scale_factor)
		draw_rect(screen.grow(-2), Color("303b3b"))
		draw_rect(screen.grow(-2), Color("9c977f"), false, 1)
		draw_string(font, screen.position + Vector2(7, 20), row[2], HORIZONTAL_ALIGNMENT_LEFT, screen.size.x - 12, 12, Color("ddd3b8"))
	var player: Vector3 = host.player.global_position
	if (1 if player.y > 2.8 else 0) == floor_index:
		draw_circle(offset + Vector2(player.x, player.z) * scale_factor, 5, Color("e5bd70"))
	for p: Vector2 in [Vector2(-13, 4), Vector2(13, 10)]:
		draw_string(font, offset + p * scale_factor, "↕", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d8bd85"))
