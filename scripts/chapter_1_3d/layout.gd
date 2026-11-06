class_name ApartmentLayout3D
extends RefCounted

const FLOOR_HEIGHT: float = 4.2
# Rectangles are X/Z metres; stairs belong to adjacent halls, not extra zones.
const ROOMS: Dictionary = {
	"hall": [0, Rect2(-12, -7, 8, 14), "Прихожая", "wood"],
	"living": [0, Rect2(-4, -7, 8, 7), "Гостиная", "wood"],
	"dining": [0, Rect2(4, -7, 8, 7), "Столовая", "wood"],
	"kitchen": [0, Rect2(4, 0, 8, 7), "Кухня", "tile"],
	"back_hall": [0, Rect2(-4, 0, 8, 7), "Служебный коридор", "wood"],
	"utility": [0, Rect2(-4, 7, 16, 7), "Постирочная", "tile"],
	"storage": [0, Rect2(-12, 7, 8, 7), "Кладовая", "concrete"],
	"gallery": [1, Rect2(-12, 0, 16, 7), "Галерея", "wood"],
	"bedroom": [1, Rect2(-12, -7, 8, 7), "Спальня", "wood"],
	"dressing": [1, Rect2(-4, -7, 8, 7), "Гардеробная", "wood"],
	"guest": [1, Rect2(4, -7, 8, 14), "Гостевая", "wood"],
	"winter_garden": [1, Rect2(4, 7, 8, 7), "Зимний сад", "tile"],
	"study": [1, Rect2(-4, 7, 8, 7), "Кабинет", "wood"],
	"bathroom": [1, Rect2(-12, 7, 8, 7), "Ванная", "tile"]
}
const CONNECTIONS: Array[Array] = [
	["hall", "living"], ["living", "dining"], ["dining", "kitchen"],
	["kitchen", "back_hall"], ["back_hall", "hall"], ["kitchen", "utility"],
	["back_hall", "utility"], ["hall", "storage"],
	["gallery", "bedroom"], ["bedroom", "dressing"], ["dressing", "guest"],
	["guest", "gallery"], ["gallery", "bathroom"], ["guest", "winter_garden"],
	["gallery", "study", "study_door"], ["study", "winter_garden", "study_door_side"]
]
# Local camera offsets and focus offsets, authored per room. Metres, Y up.
const CAMERAS: Dictionary = {
	"bedroom": [Vector3(5.0, 5.6, 7.0), Vector3(0.2, 0.9, -0.2)],
	"gallery": [Vector3(7, 8.5, 10), Vector3(0, 0.7, 0)],
	"hall": [Vector3(6.0, 9.2, 11), Vector3(0, 0.7, -1)],
	"living": [Vector3(6.5, 7.2, 8), Vector3(0, 0.8, -0.2)],
	"dining": [Vector3(-6.0, 7.1, 8), Vector3(0, 0.7, 0)],
	"kitchen": [Vector3(-6.5, 7.5, 8.5), Vector3(0, 0.8, -0.5)],
	"back_hall": [Vector3(6, 8, 9), Vector3(0, 0.7, 0)],
	"utility": [Vector3(9, 10, 12), Vector3(0, 0.7, 0)],
	"storage": [Vector3(6, 7, 8), Vector3(0, 0.8, 0)],
	"dressing": [Vector3(-5.5, 7.0, 8.0), Vector3(0, 0.8, 0)],
	"guest": [Vector3(-7, 9.0, 11), Vector3(0, 0.8, 0)],
	"winter_garden": [Vector3(-6, 7.0, 8), Vector3(0, 0.8, 0)],
	"study": [Vector3(-6, 7.5, 8), Vector3(0, 0.8, 0)],
	"bathroom": [Vector3(6.5, 7.0, 8), Vector3(0, 0.8, 0)]
}

static func center(id: String) -> Vector3:
	var row: Array = ROOMS[id]
	var p: Vector2 = (row[1] as Rect2).get_center()
	return Vector3(p.x, float(row[0]) * FLOOR_HEIGHT, p.y)

static func room_at(point: Vector3) -> String:
	var floor_index: int = 1 if point.y > FLOOR_HEIGHT * 0.65 else 0
	for id: String in ROOMS:
		var row: Array = ROOMS[id]
		if int(row[0]) == floor_index and (row[1] as Rect2).has_point(Vector2(point.x, point.z)):
			return id
	return "gallery" if floor_index == 1 else "hall"

static func portal(a: String, b: String) -> Vector3:
	var ra: Rect2 = ROOMS[a][1]
	var rb: Rect2 = ROOMS[b][1]
	var overlap: Rect2 = ra.intersection(rb)
	var p: Vector2 = overlap.get_center()
	# Rect2.intersection returns an empty rectangle for touching edges.
	if is_equal_approx(ra.end.x, rb.position.x) or is_equal_approx(rb.end.x, ra.position.x):
		p = Vector2(maxf(ra.position.x, rb.position.x), (maxf(ra.position.y, rb.position.y) + minf(ra.end.y, rb.end.y)) * 0.5)
	else:
		p = Vector2((maxf(ra.position.x, rb.position.x) + minf(ra.end.x, rb.end.x)) * 0.5, maxf(ra.position.y, rb.position.y))
	return Vector3(p.x, float(ROOMS[a][0]) * FLOOR_HEIGHT, p.y)
