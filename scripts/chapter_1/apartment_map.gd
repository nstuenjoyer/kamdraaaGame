extends Control

var world: ApartmentWorld
var player_position: Vector2

func _draw() -> void:
	if world == null: return
	var factor: float = minf(size.x / 4100.0, size.y / 2250.0)
	var origin: Vector2 = Vector2(size.x * 0.5 + 400 * factor, 45 * factor)
	var font: Font = get_theme_default_font()
	for id: String in ApartmentWorld.ROOMS:
		var data: Array = ApartmentWorld.ROOMS[id]
		var points: PackedVector2Array = world.corners(data[0])
		for i: int in points.size(): points[i] = points[i] * factor + origin
		draw_colored_polygon(points, Color("292e26"))
		var center: Vector2 = ApartmentWorld.iso((data[0] as Rect2).get_center()) * factor + origin
		var text: String = data[1]
		draw_string(font, center - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, NoirUI.TEXT)
	for segment: Vector4 in world.walls:
		draw_line(Vector2(segment.x, segment.y) * factor + origin, Vector2(segment.z, segment.w) * factor + origin, Color("747666"), 1.5)
	draw_circle(player_position * factor + origin, 6.0, Color("e7c58d"))
