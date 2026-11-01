class_name ApartmentWorld
extends Node2D

const WALL_SHADER: Shader = preload("res://shaders/apartment_wall.gdshader")
const DEPTH_SLICER: GDScript = preload("res://scripts/chapter_1/depth_slicer.gd")
const INTERIOR: GDScript = preload("res://scripts/chapter_1/apartment_interior.gd")
const ROOMS: Dictionary = {
	"bedroom": [Rect2(0, 0, 620, 600), "СПАЛЬНЯ", Color("566273"), "wood"],
	"hall": [Rect2(620, 0, 380, 1500), "ПРИХОЖАЯ", Color("575561"), "wood"],
	"bathroom": [Rect2(1000, 0, 560, 450), "ВАННАЯ", Color("496461"), "concrete"],
	"storage": [Rect2(1000, 450, 560, 400), "КЛАДОВАЯ", Color("5d574e"), "concrete"],
	"living": [Rect2(0, 600, 620, 900), "ГОСТИНАЯ", Color("686073"), "wood"],
	"kitchen": [Rect2(1000, 850, 560, 650), "КУХНЯ", Color("5d6666"), "concrete"],
	"gallery": [Rect2(0, 1500, 1560, 220), "ГАЛЕРЕЯ", Color("62615a"), "wood"],
	"study": [Rect2(0, 1720, 620, 640), "КАБИНЕТ", Color("62645b"), "wood"],
	"back_hall": [Rect2(620, 1720, 380, 640), "ЗАДНИЙ КОРИДОР", Color("5c5c56"), "wood"],
	"utility": [Rect2(1000, 1720, 560, 640), "ПОСТИРОЧНАЯ", Color("74796e"), "concrete"]
}
var walls: Array[Vector4] = []
var wall_faces: Array[Polygon2D] = []
var wall_materials: Array[ShaderMaterial] = []
var obstacles: Array[Rect2] = []
var interactables: Dictionary = {}
var ceiling_lights: Array[PointLight2D] = []
var graph: AStar2D = AStar2D.new()
var nav_points: Array[Vector2] = []
var floor_root: Node2D
var light_texture: GradientTexture2D
var furniture: Array[Node2D] = []
var study_open: bool = false

static func iso(point: Vector2) -> Vector2:
	return Vector2(point.x - point.y, (point.x + point.y) * 0.5)

static func grid(point: Vector2) -> Vector2:
	return Vector2(point.y + point.x * 0.5, point.y - point.x * 0.5)

func build() -> void:
	name = "World"
	y_sort_enabled = true
	floor_root = Node2D.new()
	floor_root.name = "Floor"
	floor_root.z_index = -20
	add_child(floor_root)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	light_texture = GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1, 0.5)
	light_texture.width = 512
	light_texture.height = 512
	for id: String in ROOMS:
		var room: Array = ROOMS[id]
		var rect: Rect2 = room[0]
		var floor_polygon: Polygon2D = polygon(floor_root, corners(rect), room[2])
		if room[3] == "wood":
			floor_polygon.texture = load("res://assets/textures/chapter_1/worn_oak.png")
			floor_polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			floor_polygon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			floor_polygon.uv = PackedVector2Array([rect.position * 8.0, (rect.position + Vector2(rect.size.x, 0)) * 8.0, rect.end * 8.0, (rect.position + Vector2(0, rect.size.y)) * 8.0])
			floor_polygon.color = Color("b3ada1")
		if id == "bathroom":
			var tiles: ShaderMaterial = ShaderMaterial.new()
			tiles.shader = preload("res://shaders/bath_tiles.gdshader")
			floor_polygon.material = tiles
			floor_polygon.color = Color.WHITE
		floor_polygon.set_meta("footstep_surface", room[3])
		if room[3] == "concrete" and id != "bathroom": _floor_pattern(rect, true)
		var lamp: PointLight2D = light(iso(rect.get_center()), Color("f6ddae"), 1.05, 2.5)
		lamp.enabled = false
		ceiling_lights.append(lamp)
	# Exterior and partitions. Every visual wall uses the same ground segment for physics, shadows and ray tests.
	wall(Vector2(0, 0), Vector2(730, 0))
	wall(Vector2(890, 0), Vector2(1560, 0))
	wall(Vector2(0, 0), Vector2(0, 2360))
	wall(Vector2(1560, 0), Vector2(1560, 2360))
	wall(Vector2(0, 2360), Vector2(1560, 2360))
	partition(Vector2(0, 1720), Vector2(1560, 1720), [Vector2(390, 550), Vector2(730, 900), Vector2(1160, 1340)])
	partition(Vector2(620, 1720), Vector2(620, 2360), [Vector2(2000, 2160)])
	partition(Vector2(1000, 1720), Vector2(1000, 2360), [Vector2(2010, 2180)])
	partition(Vector2(620, 0), Vector2(620, 1500), [Vector2(350, 500), Vector2(1040, 1210)])
	partition(Vector2(1000, 0), Vector2(1000, 1500), [Vector2(160, 360), Vector2(590, 750), Vector2(1110, 1280)])
	partition(Vector2(0, 600), Vector2(620, 600), [])
	partition(Vector2(1000, 450), Vector2(1560, 450), [])
	partition(Vector2(1000, 850), Vector2(1560, 850), [])
	partition(Vector2(0, 1500), Vector2(1560, 1500), [Vector2(390, 550), Vector2(730, 900), Vector2(1160, 1340)])
	_furnish()
	INTERIOR.furnish(self)
	update_barriers()
	for object: Node2D in furniture:
		DEPTH_SLICER.bake(self, object)
	DEPTH_SLICER.sprite(self, get_node("Bed"), load("res://assets/textures/chapter_1/bed.png"), 30.0)
	DEPTH_SLICER.sprite(self, get_node("Sofa"), load("res://assets/textures/chapter_1/sofa.png"), 45.0)
	var wood_material: ShaderMaterial = ShaderMaterial.new()
	wood_material.shader = load("res://shaders/furniture_grain.gdshader")
	wood_material.set_shader_parameter("grain_texture", load("res://assets/textures/chapter_1/worn_oak.png"))
	for part: Node in get_children():
		if part is Polygon2D and str(part.get_meta("prop_id", "")) in ["StudyDesk", "KeyCabinet", "LivingShelf", "StudyBookcase", "Table", "KitchenTable", "Bedside", "Counter", "StudyDoor", "StudySideDoor", "Cupboard", "TelevisionStand"]:
			part.material = wood_material
	_build_navigation()

func update_barriers() -> void:
	var barriers: PackedVector4Array = PackedVector4Array(walls)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(walls.size()) # Zero means a full-height partition.
	for rect: Rect2 in obstacles:
		var height: float = 0.0
		for object: Node2D in furniture:
			if object.get_meta("footprint",Rect2()) == rect:
				height = float(object.get_meta("height",0.0))
				break
		var points: PackedVector2Array = corners(rect)
		for i: int in 4:
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % 4]
			barriers.append(Vector4(a.x, a.y, b.x, b.y))
			heights.append(height)
	assert(barriers.size() <= 256)
	for i: int in wall_materials.size():
		wall_materials[i].set_shader_parameter("barriers", barriers)
		wall_materials[i].set_shader_parameter("barrier_heights", heights)
		wall_materials[i].set_shader_parameter("barrier_count", barriers.size())
		wall_materials[i].set_shader_parameter("own_barrier", wall_faces[i].get_meta("barrier_id"))

func set_study_open(opened: bool) -> void:
	if study_open == opened: return
	study_open = opened
	interactables.study_door.visible = not opened
	interactables.study_door_side.visible = not opened
	for id: String in ["StudyDoor", "StudySideDoor"]:
		var door: Node2D = get_node(id)
		door.visible = not opened
		door.collision_layer = 0 if opened else 1
		var footprint: Rect2 = door.get_meta("footprint")
		obstacles.erase(footprint)
		if not opened: obstacles.append(footprint)
		for child: Node in get_children():
			if child.has_meta("prop_id") and str(child.get_meta("prop_id")) == id: child.visible = not opened
	graph.clear()
	nav_points.clear()
	_build_navigation()
	update_barriers()

func corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([iso(rect.position), iso(rect.position + Vector2(rect.size.x, 0)), iso(rect.end), iso(rect.position + Vector2(0, rect.size.y))])

func polygon(parent: Node, points: PackedVector2Array, color: Color) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = points
	poly.color = color
	parent.add_child(poly)
	return poly

func line(parent: Node, points: PackedVector2Array, color: Color, width: float = 1.0) -> Line2D:
	var result: Line2D = Line2D.new()
	result.points = points
	result.default_color = color
	result.width = width
	parent.add_child(result)
	return result

func label(parent: Node, pos: Vector2, text: String, font_size: int = 14, color: Color = Color("cbd6dc")) -> Label:
	var result: Label = Label.new()
	result.position = pos
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func light(pos: Vector2, color: Color, energy: float, scale_factor: float) -> PointLight2D:
	var result: PointLight2D = PointLight2D.new()
	result.position = pos
	result.texture = light_texture
	result.texture_scale = scale_factor
	result.color = color
	result.energy = energy
	result.shadow_enabled = true
	result.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	result.range_item_cull_mask = 5
	add_child(result)
	return result

func _floor_pattern(rect: Rect2, tile: bool) -> void:
	var step_size: int = 48 if tile else 36
	for x: int in range(int(rect.position.x), int(rect.end.x), step_size):
		line(floor_root, PackedVector2Array([iso(Vector2(x, rect.position.y)), iso(Vector2(x, rect.end.y))]), Color(0.12, 0.15, 0.2, 0.32))
	for y: int in range(int(rect.position.y), int(rect.end.y), 48 if tile else 180):
		line(floor_root, PackedVector2Array([iso(Vector2(rect.position.x, y)), iso(Vector2(rect.end.x, y))]), Color(0.12, 0.15, 0.2, 0.24))

func partition(a: Vector2, b: Vector2, gaps: Array[Vector2]) -> void:
	var vertical: bool = is_equal_approx(a.x, b.x)
	var cursor: float = a.y if vertical else a.x
	for gap: Vector2 in gaps:
		wall(Vector2(a.x, cursor) if vertical else Vector2(cursor, a.y), Vector2(a.x, gap.x) if vertical else Vector2(gap.x, a.y))
		cursor = gap.y
	wall(Vector2(a.x, cursor) if vertical else Vector2(cursor, a.y), b)

func wall(a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 1.0:
		return
	var start: Vector2 = iso(a)
	var end: Vector2 = iso(b)
	walls.append(Vector4(start.x, start.y, end.x, end.y))
	var body: StaticBody2D = StaticBody2D.new()
	body.position = (start + end) * 0.5
	add_child(body)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(start.distance_to(end) + 6.0, 10.0)
	collision.shape = shape
	collision.rotation = (end - start).angle()
	body.add_child(collision)
	var sections: int = ceili(start.distance_to(end) / 64.0)
	for section: int in sections:
		var from: Vector2 = start.lerp(end, float(section) / sections)
		var to: Vector2 = start.lerp(end, float(section + 1) / sections)
		var visual: Node2D = Node2D.new()
		visual.position = (from + to) * 0.5
		add_child(visual)
		var local_a: Vector2 = from - visual.position
		var local_b: Vector2 = to - visual.position
		var poly: Polygon2D = polygon(visual, PackedVector2Array([local_a, local_b, local_b - Vector2(0, 66), local_a - Vector2(0, 66)]), Color("8e9aab"))
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = WALL_SHADER
		mat.set_shader_parameter("wall_start", from)
		mat.set_shader_parameter("wall_end", to)
		mat.set_shader_parameter("bathroom_tiles", (ROOMS.bathroom[0] as Rect2).grow(2).has_point((a+b)*0.5))
		poly.material = mat
		poly.set_meta("barrier_id", walls.size() - 1)
		wall_faces.append(poly)
		wall_materials.append(mat)
		var rim: Line2D = line(visual, PackedVector2Array([local_a - Vector2(0, 66), local_b - Vector2(0, 66)]), Color("a0b1c6"), 2.0)
		rim.material = mat
	var occluder: LightOccluder2D = LightOccluder2D.new()
	var occlusion: OccluderPolygon2D = OccluderPolygon2D.new()
	occlusion.polygon = PackedVector2Array([start - body.position, end - body.position])
	occlusion.closed = false
	occluder.occluder = occlusion
	occluder.occluder_light_mask = 1
	body.add_child(occluder)

func box(id: String, rect: Rect2, height: float, color: Color, title: String = "", blocking: bool = true) -> Node2D:
	var object: Node2D = StaticBody2D.new() if blocking else Node2D.new()
	object.name = id
	object.position = iso(rect.get_center())
	object.set_meta("height", height)
	object.set_meta("footprint", rect)
	add_child(object)
	if height <= 3.0: object.z_index = -18
	else: furniture.append(object)
	var points: PackedVector2Array = corners(rect)
	for i: int in points.size():
		points[i] -= object.position
	var top: PackedVector2Array = points.duplicate()
	for i: int in top.size():
		top[i] -= Vector2(0, height)
	polygon(object, PackedVector2Array([points[1], points[2], top[2], top[1]]), color.darkened(0.38)).set_meta("floor_depths", PackedFloat32Array([points[1].y + object.position.y, points[2].y + object.position.y, points[2].y + object.position.y, points[1].y + object.position.y]))
	polygon(object, PackedVector2Array([points[2], points[3], top[3], top[2]]), color.darkened(0.2)).set_meta("floor_depths", PackedFloat32Array([points[2].y + object.position.y, points[3].y + object.position.y, points[3].y + object.position.y, points[2].y + object.position.y]))
	var top_poly: Polygon2D = polygon(object, top, color)
	var top_depths: PackedFloat32Array = PackedFloat32Array()
	for point: Vector2 in points: top_depths.append(point.y + object.position.y)
	top_poly.set_meta("floor_depths", top_depths)
	line(object, PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), color.lightened(0.16), 1.5)
	object.set_meta("title", title)
	if blocking:
		obstacles.append(rect)
		var collision: CollisionPolygon2D = CollisionPolygon2D.new()
		collision.polygon = points
		object.add_child(collision)
		var occluder: LightOccluder2D = LightOccluder2D.new()
		var occlusion: OccluderPolygon2D = OccluderPolygon2D.new()
		occlusion.polygon = points
		occluder.occluder = occlusion
		occluder.occluder_light_mask = 1
		object.add_child(occluder)
	return object

func item(id: String, pos: Vector2, title: String, kind: String = "paper") -> Node2D:
	var object: Node2D = Node2D.new()
	object.name = id
	object.position = iso(pos)
	object.z_index = -16
	object.set_meta("title", title)
	object.set_meta("kind", kind)
	add_child(object)
	interactables[id] = object
	var color: Color = Color("d4cfb5")
	match kind:
		"metal": color = Color("a9c5ca")
		"plastic": color = Color("8fb3b8")
		"glass": color = Color("81a4a7")
		"wood": color = Color("b58b68")
	var shape: PackedVector2Array = PackedVector2Array([Vector2(-13, 0), Vector2(1, 7), Vector2(15, 0), Vector2(1, -7)])
	if id in ["front_key", "cupboard_key"]:
		shape = PackedVector2Array([Vector2(-14, -1), Vector2(4, -1), Vector2(4, -5), Vector2(13, -5), Vector2(16, 0), Vector2(13, 5), Vector2(4, 5), Vector2(4, 2), Vector2(-9, 2), Vector2(-9, 6), Vector2(-14, 6)])
	elif id in ["flashlight", "pepper", "screwdriver", "fuse"]:
		shape = PackedVector2Array([Vector2(-13, -4), Vector2(9, -4), Vector2(16, -8), Vector2(16, 8), Vector2(9, 4), Vector2(-13, 4)])
	polygon(object, shape, color)
	_item_art(object, id)
	return object

func target(id: String, pos: Vector2, title: String, kind: String = "wood") -> void:
	var object: Node2D = Node2D.new()
	object.position = iso(pos)
	object.set_meta("title", title)
	object.set_meta("kind", kind)
	add_child(object)
	interactables[id] = object

func _furnish() -> void:
	var bed: Node2D = box("Bed", Rect2(75, 90, 160, 240), 26, Color("666582"), "Кровать")
	var pillow: PackedVector2Array = corners(Rect2(90, 110, 185, 75))
	for i: int in pillow.size():
		pillow[i] -= bed.position + Vector2(0, 30)
	polygon(bed, pillow, Color("bcc8d6"))
	box("Bedside", Rect2(350, 80, 100, 85), 40, Color("725f58"), "Тумбочка · зарядка")
	box("BedroomShelf", Rect2(20, 430, 150, 105), 52, Color("6f635a"))
	box("Chair", Rect2(500, 130, 60, 70), 26, Color("635e70"))
	box("Rug", Rect2(230, 310, 260, 210), 0, Color("675262"), "", false)
	target("bed", Vector2(255, 240), "Обыскать кровать")
	item("pills", Vector2(330, 310), "Блистер · 2 таблетки", "plastic").visible = false
	item("front_key", Vector2(200, 2140), "Ключ от входной двери", "metal").visible = false
	item("phone", Vector2(410, 205), "Разряженный телефон", "plastic")
	item("flashlight", Vector2(190, 480), "Карманный фонарик", "metal")
	item("bedside", Vector2(410, 280), "Листок у кровати")
	target("charger", Vector2(465, 155), "Зарядка телефона", "plastic")
	# A window with curtains, glass reflections and broad street lighting, without blind-slat shadow artifacts.
	var window: Node2D = box("Window", Rect2(20, 20, 290, 14), 62, Color("94b7c3"), "Окно", false)
	line(window, PackedVector2Array([Vector2(-100, -90), Vector2(-15, -48)]), Color("6b8796"), 16)
	line(window, PackedVector2Array([Vector2(10, -38), Vector2(105, 10)]), Color("6b8796"), 16)
	light(iso(Vector2(180, 110)), Color("9ac4eb"), 0.8, 1.6)
	box("HallMirror", Rect2(935, 350, 38, 130), 65, Color("82969d"), "СРОЧНО УХОДИ")
	target("hall_mirror", Vector2(880, 410), "Надпись на зеркале", "glass")
	box("Cupboard", Rect2(885, 70, 90, 200), 88, Color("76605d"), "Запертый шкаф")
	target("cupboard", Vector2(835, 200), "Шкаф с пальто")
	box("FrontDoor", Rect2(735, 5, 150, 12), 74, Color("827067"), "Входная дверь")
	target("exit", Vector2(810, 72), "Входная дверь", "metal")
	box("Bath", Rect2(1280, 70, 220, 125), 25, Color("a0a9a8"), "Ванна")
	box("Sink", Rect2(1090, 55, 110, 90), 34, Color("a5b4ba"), "Не выходи.")
	target("bathroom", Vector2(1145, 200), "Зеркало в ванной", "glass")
	item("bath_note", Vector2(1450, 300), "Записка под полотенцем")
	target("hide_bath", Vector2(1450, 365), "Спрятаться за ванной")
	box("Tools", Rect2(1300, 490, 180, 100), 38, Color("88725c"), "Инструменты")
	item("screwdriver", Vector2(1300, 2140), "Отвёртка", "metal")
	box("Fusebox", Rect2(1460, 660, 60, 120), 70, Color("82949c"), "Электрощиток")
	target("fusebox", Vector2(1380, 710), "Осмотреть щиток", "metal")
	box("Sofa", Rect2(65, 715, 250, 110), 37, Color("6b7c7c"), "Диван")
	box("Table", Rect2(270, 1000, 180, 130), 31, Color("9a7a67"), "Стол")
	box("LivingShelf", Rect2(25, 1170, 100, 250), 57, Color("77675c"))
	item("diary", Vector2(360, 850), "Личный дневник").visible = false
	item("vase", Vector2(410, 900), "Разбитая ваза", "glass")
	for i: int in range(9):
		var offset: Vector2 = Vector2(sin(i * 2.4) * 34, cos(i * 1.7) * 18)
		polygon(interactables.vase, PackedVector2Array([offset, offset + Vector2(8, -3), offset + Vector2(4, 7)]), Color("adbdc4"))
	item("cupboard_key", Vector2(410, 900), "Маленький ключ от шкафа", "metal").visible = false
	item("throwable", Vector2(160, 1100), "Целая керамическая ваза", "glass")
	item("rope", Vector2(175, 1360), "Бельевой шнур", "plastic")
	target("hide_sofa", Vector2(150, 925), "Спрятаться за диваном")
	box("Counter", Rect2(1080, 890, 360, 100), 39, Color("a49b83"), "Кухонный гарнитур")
	box("Fridge", Rect2(1440, 1120, 80, 130), 86, Color("9da9b1"), "Холодильник")
	item("fuse", Vector2(1180, 1045), "Новый предохранитель", "metal")
	item("heavy", Vector2(1380, 1060), "Тяжёлая чугунная сковорода", "metal")
	box("KitchenTable", Rect2(1100, 1280, 180, 100), 32, Color("98866c"))
	light(iso(Vector2(1480, 1400)), Color("b8c8db"), 0.55, 1.8)
	box("CoatFallen", Rect2(850, 270, 80, 130), 3, Color("342f3d"), "Пальто и вешалка", false).visible = false
	_detail_furniture()

func ellipse(parent: Node2D, center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 32:
		points.append(center + Vector2(cos(float(i) / 32 * TAU), sin(float(i) / 32 * TAU)) * radius)
	polygon(parent, points, color)

func surface(parent: Node2D, rect: Rect2, height: float, color: Color) -> Polygon2D:
	var points: PackedVector2Array = corners(rect)
	var depths: PackedFloat32Array = PackedFloat32Array()
	for point: Vector2 in points: depths.append(point.y)
	for i: int in points.size(): points[i] -= parent.position + Vector2(0, height)
	var result: Polygon2D = polygon(parent, points, color)
	result.set_meta("floor_depths", depths)
	return result

func _item_art(object: Node2D, id: String) -> void:
	match id:
		"phone":
			polygon(object, PackedVector2Array([Vector2(-12, -10), Vector2(9, -6), Vector2(13, 8), Vector2(-10, 5)]), Color("242d3e"))
			line(object, PackedVector2Array([Vector2(-8, -7), Vector2(5, -4), Vector2(8, 3), Vector2(-6, 1), Vector2(-8, -7)]), Color("8ea3b1"), 1)
		"pills":
			for x: int in 3:
				for y: int in 2:
					ellipse(object, Vector2(-7 + x * 7, -3 + y * 5), Vector2(2.4, 1.6), Color("b8d0d8"))
		"flashlight":
			line(object, PackedVector2Array([Vector2(-13, 2), Vector2(8, -2)]), Color("35465b"), 8)
			ellipse(object, Vector2(11, -2), Vector2(5, 7), Color("d4ddcf"))
		"screwdriver":
			line(object, PackedVector2Array([Vector2(-13, 3), Vector2(3, 0)]), Color("ad6b4f"), 7)
			line(object, PackedVector2Array([Vector2(3, 0), Vector2(20, -4)]), Color("a8b7c5"), 2)
		"fuse":
			line(object, PackedVector2Array([Vector2(-9, 0), Vector2(10, 0)]), Color("d0ddd6"), 6)
			line(object, PackedVector2Array([Vector2(-9, -3), Vector2(-9, 3)]), Color("60758c"), 4)
			line(object, PackedVector2Array([Vector2(10, -3), Vector2(10, 3)]), Color("60758c"), 4)
		"diary":
			polygon(object, PackedVector2Array([Vector2(-17, -3), Vector2(0, -13), Vector2(20, -2), Vector2(2, 9)]), Color("825b66"))
			line(object, PackedVector2Array([Vector2(-12, -4), Vector2(3, 5)]), Color("d5cbb1"), 2)
		"throwable":
			polygon(object, PackedVector2Array([Vector2(-5, -29), Vector2(5, -29), Vector2(4, -19), Vector2(12, -10), Vector2(8, 2), Vector2(-8, 2), Vector2(-12, -10), Vector2(-4, -19)]), Color("76949f"))
			ellipse(object, Vector2(0, -29), Vector2(6, 2), Color("b2c6cb"))
		"rope":
			for i: int in 3: ellipse(object, Vector2(i * 2, -i), Vector2(12 - i * 2, 7 - i), Color("b7ab8a"))
			ellipse(object, Vector2(4, -3), Vector2(4, 2), Color("5d6170"))
		"heavy":
			ellipse(object, Vector2.ZERO, Vector2(14, 8), Color("242c36"))
			line(object, PackedVector2Array([Vector2(10, 1), Vector2(30, 6)]), Color("343b46"), 5)

func _detail_furniture() -> void:
	var bed: Node2D = get_node("Bed")
	for i: int in 4:
		surface(bed, Rect2(82, 215 + i * 34, 205, 5), 27, Color("7d7b96"))
	surface(bed, Rect2(90, 110, 82, 64), 32, Color("c3d0d9"))
	surface(bed, Rect2(185, 110, 82, 64), 32, Color("becbd6"))
	var sofa: Node2D = get_node("Sofa")
	for i: int in 3: surface(sofa, Rect2(78 + i * 86, 755, 79, 74), 39, Color("8a9896"))
	surface(sofa, Rect2(65, 715, 280, 28), 64, Color("899994"))
	var table: Node2D = get_node("Table")
	surface(table, Rect2(300, 1020, 75, 45), 32, Color("bec2b3"))
	var counter: Node2D = get_node("Counter")
	surface(counter, Rect2(1110, 907, 105, 65), 40, Color("566b76"))
	surface(counter, Rect2(1124, 917, 78, 42), 40, Color("2f434e"))
	var faucet: Vector2 = iso(Vector2(1135, 902)) - counter.position
	line(counter, PackedVector2Array([faucet - Vector2(0, 39), faucet - Vector2(0, 58), faucet + Vector2(18, -49)]), Color("b8cbd0"), 4)
	for x: int in 2:
		for y: int in 2:
			var ring_pos: Vector2 = iso(Vector2(1300 + x * 65, 920 + y * 39)) - counter.position - Vector2(0, 41)
			ellipse(counter, ring_pos, Vector2(21, 9), Color("3b424c"))
			ellipse(counter, ring_pos, Vector2(13, 5), Color("6f7174"))
	var tub: Node2D = get_node("Bath")
	surface(tub, Rect2(1290, 80, 200, 105), 27, Color("d1d9d8"))
	surface(tub, Rect2(1307, 92, 165, 78), 27, Color("596e77"))
	var sink: Node2D = get_node("Sink")
	surface(sink, Rect2(1100, 65, 90, 70), 35, Color("d4dad6"))
	surface(sink, Rect2(1115, 78, 62, 44), 35, Color("536b75"))
	_mirror(get_node("HallMirror"), Vector2(965, 350), Vector2(965, 480), "СРОЧНО УХОДИ", 11)
	_mirror(sink, Vector2(1090, 55), Vector2(1200, 55), "Не выходи.", 15)
	var fridge: Node2D = get_node("Fridge")
	var handle: Vector2 = iso(Vector2(1440, 1200)) - fridge.position
	line(fridge, PackedVector2Array([handle - Vector2(0, 52), handle - Vector2(0, 33)]), Color("515e6c"), 4)
	var cupboard: Node2D = get_node("Cupboard")
	var edge: Vector2 = iso(Vector2(975, 170)) - cupboard.position
	line(cupboard, PackedVector2Array([edge - Vector2(0, 82), edge - Vector2(0, 3)]), Color("3c3741"), 2)
	ellipse(cupboard, edge - Vector2(9, 35), Vector2(3, 3), Color("c4b58e"))
	var coat: Node2D = get_node("CoatFallen")
	line(coat, PackedVector2Array([Vector2(-30, -10), Vector2(15, 10), Vector2(34, -10)]), Color("afac9b"), 3)
	polygon(coat, PackedVector2Array([Vector2(-25, -15), Vector2(-10, -30), Vector2(6, -12), Vector2(36, -4), Vector2(25, 14), Vector2(-17, 12)]), Color("464353"))
	var fusebox: Node2D = get_node("Fusebox")
	var center: Vector2 = iso(Vector2(1460, 720)) - fusebox.position - Vector2(0, 38)
	for i: int in 3:
		line(fusebox, PackedVector2Array([center + Vector2(i * 9, -12), center + Vector2(i * 9, 4)]), Color("394956"), 5)

func _mirror(parent: Node2D, a: Vector2, b: Vector2, inscription: String, size_value: int) -> void:
	# A small upright mirror is one coherent drawable, including its frame and inscription.
	# The surrounding large cabinet is depth sliced independently.
	var visual: Node2D = Node2D.new()
	visual.name = str(parent.name) + "Glass"
	visual.position = iso((a + b) * 0.5)
	add_child(visual)
	parent = visual
	var start: Vector2 = iso(a) - visual.position - Vector2(0, 44)
	var end: Vector2 = iso(b) - visual.position - Vector2(0, 44)
	var points: PackedVector2Array = PackedVector2Array([start, end, end - Vector2(0, 65), start - Vector2(0, 65)])
	polygon(parent, points, Color("7596a7")).set_meta("floor_depths", PackedFloat32Array([iso(a).y, iso(b).y, iso(b).y, iso(a).y]))
	line(parent, PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("b0bbc0"), 4)
	line(parent, PackedVector2Array([start.lerp(end, 0.15) - Vector2(0, 10), start.lerp(end, 0.75) - Vector2(0, 50)]), Color(0.75, 0.86, 0.9, 0.35), 2)
	label(parent, (start + end) * 0.5 - Vector2(43, 45), inscription, size_value, Color("b56c72"))

func room_at(point: Vector2) -> String:
	var logical: Vector2 = grid(point)
	for id: String in ROOMS:
		if (ROOMS[id][0] as Rect2).has_point(logical):
			return id
	return "hall"

func can_walk(point: Vector2, margin: float = 20.0) -> bool:
	var logical: Vector2 = grid(point)
	if not Rect2(22, 22, 1516, 2316).has_point(logical):
		return false
	for rect: Rect2 in obstacles:
		if rect.grow(margin).has_point(logical):
			return false
	for segment: Vector4 in walls:
		if Geometry2D.get_closest_point_to_segment(point, Vector2(segment.x, segment.y), Vector2(segment.z, segment.w)).distance_to(point) < margin:
			return false
	return true

func clear_line(a: Vector2, b: Vector2, furniture: bool = true) -> bool:
	for segment: Vector4 in walls:
		if Geometry2D.segment_intersects_segment(a, b, Vector2(segment.x, segment.y), Vector2(segment.z, segment.w)) != null:
			return false
	if furniture:
		for rect: Rect2 in obstacles:
			var points: PackedVector2Array = corners(rect)
			for i: int in 4:
				if Geometry2D.segment_intersects_segment(a, b, points[i], points[(i + 1) % 4]) != null:
					return false
	return true

func _build_navigation() -> void:
	var cells: Dictionary = {}
	for x: int in range(40, 1560, 40):
		for y: int in range(40, 2360, 40):
			var point: Vector2 = iso(Vector2(x, y))
			if can_walk(point, 21.0):
				var index: int = nav_points.size()
				graph.add_point(index, point)
				nav_points.append(point)
				cells[Vector2i(x, y)] = index
	for cell: Vector2i in cells:
		for direction: Vector2i in [Vector2i(40, 0), Vector2i(0, 40)]:
			var adjacent: Vector2i = cell + direction
			if cells.has(adjacent) and clear_line(graph.get_point_position(cells[cell]), graph.get_point_position(cells[adjacent])):
				graph.connect_points(cells[cell], cells[adjacent])
	# Thin pockets between furniture and the exterior are not navigable by a full-width actor.
	# Keep only the connected apartment component so nearest-point queries cannot target these pockets.
	var origin: int = graph.get_closest_point(iso(Vector2(370, 320)))
	var disconnected: Array[Vector2] = []
	for point: Vector2 in nav_points:
		var id: int = graph.get_closest_point(point)
		if graph.get_id_path(origin, id).is_empty():
			disconnected.append(point)
	for point: Vector2 in disconnected:
		graph.remove_point(graph.get_closest_point(point))
		nav_points.erase(point)

func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	if clear_line(a, b) and can_walk(b, 18.0):
		return PackedVector2Array([b])
	return graph.get_point_path(graph.get_closest_point(a), graph.get_closest_point(b))

func update_lighting(player_pos: Vector2, direction: Vector2, torch: bool, power: bool, emission_position: Vector2 = Vector2(INF, INF), emission_height: float = 58.0) -> void:
	var height: float = clampf(emission_height, 0.0, 150.0)
	var lens: Vector2 = emission_position if emission_position.is_finite() else player_pos - Vector2(0, height)
	var ground_origin: Vector2 = lens + Vector2(0, height)
	# A raised lens is a screen-space visual. Shadow barriers stay on the floor;
	# never move that footprint through a wall merely because the arm reaches it.
	if not clear_line(player_pos, ground_origin):
		ground_origin = player_pos
		lens = ground_origin - Vector2(0, height)
	for i: int in wall_materials.size():
		var mat: ShaderMaterial = wall_materials[i]
		mat.set_shader_parameter("player_position", player_pos)
		mat.set_shader_parameter("torch_position", ground_origin)
		mat.set_shader_parameter("torch_emission_position", lens)
		mat.set_shader_parameter("torch_height", height)
		mat.set_shader_parameter("torch_direction", direction)
		mat.set_shader_parameter("torch_on", torch)
		mat.set_shader_parameter("power_on", power)

	for lamp: PointLight2D in ceiling_lights:
		lamp.enabled = power
