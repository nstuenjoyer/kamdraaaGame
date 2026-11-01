extends RefCounted

static func furnish(w: ApartmentWorld) -> void:
	# Every cluster belongs to a room and leaves a usable approach to its interactions.
	w.box("StudyDoor", Rect2(390, 1720, 160, 12), 74, Color("665748"))
	w.box("StudySideDoor", Rect2(614, 2000, 12, 160), 74, Color("665748"))
	w.target("study_door", Vector2(470, 1670), "Кабинет · заперто", "metal")
	w.target("study_door_side", Vector2(690, 2080), "Кабинет · заперто", "metal")
	w.box("StudyDesk", Rect2(270, 1840, 220, 105), 35, Color("77624a"))
	w.box("StudyChair", Rect2(355, 2000, 65, 65), 28, Color("46554e"))
	w.box("StudyBookcase", Rect2(25, 1780, 70, 290), 86, Color("5b4b3b"))
	w.box("KeyCabinet", Rect2(90, 2250, 225, 65), 64, Color("746950"))
	w.box("UtilityBench", Rect2(1190, 2230, 300, 90), 39, Color("706b5c"))
	w.box("WashingMachine", Rect2(1050, 1770, 125, 115), 55, Color("b4b3a0"))
	w.box("Boiler", Rect2(1460, 1790, 65, 160), 82, Color("9b9f91"))
	w.box("UtilityShelf", Rect2(1360, 1970, 140, 70), 62, Color("6e6654"))
	w.box("TelevisionStand", Rect2(385, 655, 190, 70), 29, Color("655745"))
	w.box("Armchair", Rect2(425, 1340, 120, 105), 37, Color("626b56"))
	w.box("KitchenChair", Rect2(1090, 1405, 55, 55), 24, Color("70654d"))
	w.box("BathToilet", Rect2(1450, 335, 70, 70), 27, Color("b4b9b1"))
	w.box("StorageCases", Rect2(1050, 480, 150, 85), 48, Color("81745c"))
	w.box("StorageBags", Rect2(1100, 770, 100, 45), 24, Color("7a7362"))
	w.box("GalleryPlant", Rect2(40, 1580, 55, 55), 18, Color("7c6853"))
	w.target("jacket", Vector2(180, 420), "Осмотреть куртку Даши")
	w.target("key_rack", Vector2(1490, 1010), "Ключница у кухни", "metal")
	w.target("key_cabinet", Vector2(210, 2170), "Картотека с кодовым замком", "metal")
	w.target("desk_note", Vector2(510, 1940), "Записка на письменном столе", "paper")
	w.target("wall_clock", Vector2(480, 770), "Остановившиеся часы", "wood")
	w.target("microwave", Vector2(1250, 1005), "Часы на микроволновке", "metal")
	w.target("service_log", Vector2(1190, 2145), "Журнал отключений", "paper")
	w.target("sofa_search", Vector2(355, 780), "Осмотреть диванные подушки")
	w.target("tap", Vector2(1210, 240), "Капающий кран", "metal")
	w.target("books", Vector2(145, 1230), "Книжная полка", "paper")
	w.target("records", Vector2(515, 1280), "Проигрыватель и пластинки", "plastic")
	w.target("photo", Vector2(490, 1860), "Рамка с фотографией", "glass")
	w.target("laundry", Vector2(1195, 1850), "Барабан стиральной машины", "metal")
	w.target("pantry", Vector2(1240, 560), "Открытые коробки", "paper")
	w.target("meal", Vector2(1310, 1360), "Накрытый стол", "glass")
	w.target("coat_hook", Vector2(750, 320), "Пустые крючки в прихожей")
	w.interactables.hide_bath.position = ApartmentWorld.iso(Vector2(1380, 365))
	rug(w, w.get_node("Rug"), Rect2(230, 310, 260, 210), Color("74604f"))
	var living_rug: Node2D = w.box("LivingCarpet", Rect2(190, 910, 370, 340), 0, Color("68513f"), "", false)
	rug(w, living_rug, Rect2(190, 910, 370, 340), Color("8d7655"))
	var study_rug: Node2D = w.box("StudyCarpet", Rect2(150, 1980, 380, 210), 0, Color("464f43"), "", false)
	rug(w, study_rug, Rect2(150, 1980, 380, 210), Color("74795c"))
	for entry: Array in [["Bedside", Rect2(365, 96, 30, 24), 42], ["Table", Rect2(325, 1050, 65, 35), 33], ["StudyDesk", Rect2(285, 1860, 75, 40), 37]]:
		papers(w, w.get_node(entry[0]), entry[1], entry[2])
	bookshelf(w, w.get_node("LivingShelf"), Rect2(25, 1170, 100, 250), 58)
	bookshelf(w, w.get_node("StudyBookcase"), Rect2(25, 1780, 70, 290), 87)
	chair(w, w.get_node("StudyChair"), Rect2(355, 2000, 65, 65), 29)
	chair(w, w.get_node("KitchenChair"), Rect2(1090, 1405, 55, 55), 25)
	plant(w, w.get_node("GalleryPlant"))
	plant(w, w.get_node("BedroomShelf"), Vector2(32, -52), 0.65)
	television(w)
	bedroom(w)
	kitchen(w)
	utility(w)
	wall_details(w)
	for entry: Array in [["Table", Rect2(270, 1000, 180, 130), 31.0], ["StudyDesk", Rect2(270, 1840, 220, 105), 35.0], ["KitchenTable", Rect2(1100, 1280, 180, 100), 32.0]]:
		table_legs(w, w.get_node(entry[0]), entry[1], entry[2])
	for entry: Array in [["KeyCabinet", Vector2(90, 2315), Vector2(315, 2315), 64.0], ["Counter", Vector2(1080, 990), Vector2(1440, 990), 39.0]]:
		drawers(w, w.get_node(entry[0]), entry[1], entry[2], entry[3])
	var armchair: Node2D = w.get_node("Armchair")
	w.surface(armchair, Rect2(435, 1350, 100, 85), 39, Color("7e8870"))
	w.surface(armchair, Rect2(425, 1340, 120, 20), 66, Color("657058"))
	var clock: Node2D = mount(w, Vector2(520, 600))
	w.ellipse(clock, Vector2(0, -39), Vector2(21, 21), Color("5b5547"))
	w.ellipse(clock, Vector2(0, -39), Vector2(18, 18), Color("b7b19b"))
	w.line(clock, PackedVector2Array([Vector2(-13, -34), Vector2(0, -39), Vector2(-9, -50)]), Color("4c514a"), 2)
	window(w, Vector2(25, 24), Vector2(305, 24))
	window(w, Vector2(1540, 1260), Vector2(1540, 1460))
	# Small, readable traces of a life interrupted: no random loot carpet.
	for note: Array in [[Vector2(160, 480), Color("706b68")], [Vector2(220, 535), Color("988c75")], [Vector2(490, 1190), Color("bbb7a7")], [Vector2(1260, 1550), Color("958e74")]]:
		var flat: Node2D = Node2D.new()
		flat.position = ApartmentWorld.iso(note[0])
		flat.z_index = -17
		w.add_child(flat)
		w.polygon(flat, PackedVector2Array([Vector2(-12, 0), Vector2(3, -7), Vector2(18, 1), Vector2(2, 9)]), note[1])

static func rug(w: ApartmentWorld, object: Node2D, rect: Rect2, color: Color) -> void:
	w.surface(object, rect.grow(-10), 0.2, color)
	w.surface(object, rect.grow(-18), 0.4, color.darkened(0.32))
	for i: int in 6:
		var center: Vector2 = rect.position + Vector2(rect.size.x * (i + 0.5) / 6.0, rect.size.y * 0.5)
		w.surface(object, Rect2(center - Vector2(8, 32), Vector2(16, 64)), 0.6, color.lightened(0.08))

static func papers(w: ApartmentWorld, parent: Node2D, rect: Rect2, height: float) -> void:
	for i: int in 3:
		w.surface(parent, Rect2(rect.position + Vector2(i * 3, -i * 2), rect.size), height + i * 0.2, Color("b6b19b").darkened(i * 0.04))
	for i: int in 4:
		w.surface(parent, Rect2(rect.position + Vector2(10, 8 + i * 5), Vector2(rect.size.x - 18, 1.2)), height + 1, Color("777b71"))

static func bookshelf(w: ApartmentWorld, parent: Node2D, rect: Rect2, height: float) -> void:
	var colors: Array[Color] = [Color("62544e"), Color("777b69"), Color("91846c"), Color("465c60"), Color("8e765b")]
	var a: Vector2 = ApartmentWorld.iso(Vector2(rect.end.x, rect.position.y + 6))
	var b: Vector2 = ApartmentWorld.iso(rect.end - Vector2(0, 6))
	for shelf: int in 3:
		for i: int in 18:
			var left: Vector2 = a.lerp(b, float(i) / 18.0)
			var right: Vector2 = a.lerp(b, (i + 0.8) / 18.0)
			var base: float = 4 + shelf * (height - 6) / 3.0
			var tall: float = (height - 6) / 3.0 - 3 - (i % 4)
			var poly: Polygon2D = w.polygon(parent, PackedVector2Array([left - parent.position - Vector2(0, base), right - parent.position - Vector2(0, base), right - parent.position - Vector2(0, base + tall), left - parent.position - Vector2(0, base + tall)]), colors[(i + shelf) % colors.size()])
			poly.set_meta("floor_depths", PackedFloat32Array([left.y, right.y, right.y, left.y]))

static func table_legs(w: ApartmentWorld, parent: Node2D, rect: Rect2, height: float) -> void:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is Polygon2D:
			if count < 2:
				child.set_meta("skip_depth_bake", true)
				child.visible = false
			count += 1
	var points: PackedVector2Array = w.corners(rect.grow(-10))
	for foot: Vector2 in points:
		var local: Vector2 = foot - parent.position
		var leg: Polygon2D = w.polygon(parent, PackedVector2Array([local - Vector2(3, 0), local + Vector2(3, 0), local + Vector2(3, -height + 3), local + Vector2(-3, -height + 3)]), Color("554a3d"))
		leg.set_meta("floor_depths", PackedFloat32Array([foot.y, foot.y, foot.y, foot.y]))

static func drawers(w: ApartmentWorld, parent: Node2D, logical_a: Vector2, logical_b: Vector2, height: float) -> void:
	var a: Vector2 = ApartmentWorld.iso(logical_a)
	var b: Vector2 = ApartmentWorld.iso(logical_b)
	for row: int in 2:
		for column: int in 3:
			var left: Vector2 = a.lerp(b, column / 3.0 + 0.018)
			var right: Vector2 = a.lerp(b, (column + 1) / 3.0 - 0.018)
			var low: float = 4 + row * height * 0.45
			var high: float = low + height * 0.38
			var panel: Polygon2D = w.polygon(parent, PackedVector2Array([left - parent.position - Vector2(0, low), right - parent.position - Vector2(0, low), right - parent.position - Vector2(0, high), left - parent.position - Vector2(0, high)]), Color("7c7059").darkened(row * 0.06))
			panel.set_meta("floor_depths", PackedFloat32Array([left.y, right.y, right.y, left.y]))
			var center: Vector2 = (left + right) * 0.5 - parent.position - Vector2(0, (low + high) * 0.5)
			w.line(parent, PackedVector2Array([center - Vector2(5, 1), center + Vector2(5, 1)]), Color("b0a58b"), 2)

static func chair(w: ApartmentWorld, parent: Node2D, rect: Rect2, height: float) -> void:
	w.surface(parent, rect.grow(-6), height + 1, Color("796f58"))
	w.surface(parent, Rect2(rect.position, Vector2(rect.size.x, 9)), height + 36, Color("6b624d"))
	for side: float in [0.0, rect.size.x - 6]:
		var base: Vector2 = ApartmentWorld.iso(rect.position + Vector2(side, 0)) - parent.position
		w.line(parent, PackedVector2Array([base - Vector2(0, height), base - Vector2(0, height + 36)]), Color("6b624d"), 5)

static func plant(w: ApartmentWorld, parent: Node2D, offset: Vector2 = Vector2(0, -20), scale_value: float = 1.0) -> void:
	for i: int in 9:
		var tip: Vector2 = offset + Vector2(sin(i * 2.4) * 32, -25 - (i % 3) * 17) * scale_value
		w.line(parent, PackedVector2Array([offset, tip]), Color("414d3d"), 2)
		w.ellipse(parent, tip, Vector2(13, 4) * scale_value, Color("5d6a4b").lightened((i % 3) * 0.05))

static func television(w: ApartmentWorld) -> void:
	var stand: Node2D = w.get_node("TelevisionStand")
	var p: Vector2 = ApartmentWorld.iso(Vector2(480, 685)) - stand.position - Vector2(0, 31)
	w.polygon(stand, PackedVector2Array([p + Vector2(-56, 0), p + Vector2(52, -4), p + Vector2(49, -70), p + Vector2(-53, -67)]), Color("343a3b"))
	w.polygon(stand, PackedVector2Array([p + Vector2(-45, -9), p + Vector2(31, -12), p + Vector2(30, -58), p + Vector2(-43, -56)]), Color("242e32"))
	for y: int in 3: w.ellipse(stand, p + Vector2(42, -20 - y * 13), Vector2(3, 3), Color("7d806d"))
	w.line(stand, PackedVector2Array([p + Vector2(-15, -68), p + Vector2(-35, -97)]), Color("8a8f85"), 2)
	w.line(stand, PackedVector2Array([p + Vector2(-15, -68), p + Vector2(15, -96)]), Color("8a8f85"), 2)

static func bedroom(w: ApartmentWorld) -> void:
	var bed: Node2D = w.get_node("Bed")
	for i: int in 12:
		w.surface(bed, Rect2(80 + i * 17, 200, 1.2, 178), 28, Color(0.65, 0.68, 0.68, 0.18))
	for i: int in 4:
		w.surface(bed, Rect2(88, 240 + i * 38, 194, 2), 28, Color(0.25, 0.30, 0.34, 0.25))
	var chair_node: Node2D = w.get_node("Chair")
	chair(w, chair_node, Rect2(500, 130, 60, 70), 27)
	w.surface(chair_node, Rect2(510, 148, 41, 47), 30, Color("4a4f57"))
	var side: Node2D = w.get_node("Bedside")
	var lamp: Vector2 = ApartmentWorld.iso(Vector2(425, 110)) - side.position - Vector2(0, 41)
	w.ellipse(side, lamp, Vector2(13, 6), Color("777b69"))
	w.line(side, PackedVector2Array([lamp, lamp - Vector2(0, 30)]), Color("9b927a"), 3)
	w.polygon(side, PackedVector2Array([lamp + Vector2(-20, -29), lamp + Vector2(18, -29), lamp + Vector2(10, -50), lamp + Vector2(-12, -50)]), Color("a49673"))
	var cable: Node2D = Node2D.new()
	cable.z_index = -17
	w.add_child(cable)
	w.line(cable, PackedVector2Array([ApartmentWorld.iso(Vector2(445, 145)), ApartmentWorld.iso(Vector2(470, 200)), ApartmentWorld.iso(Vector2(430, 230))]), Color("373d3c"), 2)

static func kitchen(w: ApartmentWorld) -> void:
	var counter: Node2D = w.get_node("Counter")
	for i: int in 5:
		w.surface(counter, Rect2(1090 + i * 67, 982, 55, 4), 25, Color("665f4d"))
	var microwave: Vector2 = ApartmentWorld.iso(Vector2(1250, 935)) - counter.position - Vector2(0, 43)
	w.polygon(counter, PackedVector2Array([microwave + Vector2(-32, 0), microwave + Vector2(32, 0), microwave + Vector2(32, -27), microwave + Vector2(-32, -27)]), Color("8a8e80"))
	w.polygon(counter, PackedVector2Array([microwave + Vector2(-27, -4), microwave + Vector2(16, -4), microwave + Vector2(16, -23), microwave + Vector2(-27, -23)]), Color("303c3b"))
	var table: Node2D = w.get_node("KitchenTable")
	for p: Vector2 in [Vector2(1145, 1310), Vector2(1235, 1350)]:
		w.ellipse(table, ApartmentWorld.iso(p) - table.position - Vector2(0, 33), Vector2(22, 10), Color("c0bba2"))
		w.ellipse(table, ApartmentWorld.iso(p) - table.position - Vector2(0, 34), Vector2(14, 6), Color("9d9e88"))
	papers(w, table, Rect2(1160, 1300, 75, 25), 34)

static func utility(w: ApartmentWorld) -> void:
	var machine: Node2D = w.get_node("WashingMachine")
	var center: Vector2 = ApartmentWorld.iso(Vector2(1175, 1830)) - machine.position - Vector2(0, 26)
	w.ellipse(machine, center, Vector2(22, 25), Color("777f7b"))
	w.ellipse(machine, center, Vector2(16, 18), Color("374b51"))
	var bench: Node2D = w.get_node("UtilityBench")
	for i: int in 6:
		w.surface(bench, Rect2(1205 + i * 42, 2250, 28, 24), 41, Color("707c72").lightened((i % 3) * 0.08))
	papers(w, bench, Rect2(1360, 2260, 65, 35), 42)

static func wall_details(w: ApartmentWorld) -> void:
	for base: Vector2 in [Vector2(550, 110), Vector2(570, 1250), Vector2(1510, 1400), Vector2(590, 1880)]:
		var object: Node2D = mount(w, base)
		for i: int in 9:
			w.line(object, PackedVector2Array([Vector2(i * 5 - 22, -8), Vector2(i * 5 - 22, -43)]), Color("9b9c87"), 3)
	for base: Vector2 in [Vector2(260, 610), Vector2(1000, 440), Vector2(150, 1740)]:
		var frame: Node2D = mount(w, base)
		w.polygon(frame, PackedVector2Array([Vector2(-33, -60), Vector2(34, -60), Vector2(34, -18), Vector2(-33, -18)]), Color("4f4c40"))
		w.polygon(frame, PackedVector2Array([Vector2(-27, -55), Vector2(28, -55), Vector2(28, -23), Vector2(-27, -23)]), Color("93927a"))
		w.line(frame, PackedVector2Array([Vector2(-18, -30), Vector2(-5, -48), Vector2(8, -28), Vector2(19, -43)]), Color("5b6558"), 4)

static func window(w: ApartmentWorld, a: Vector2, b: Vector2) -> void:
	var frame: Node2D = Node2D.new()
	frame.position = ApartmentWorld.iso((a + b) * 0.5)
	w.add_child(frame)
	var start: Vector2 = ApartmentWorld.iso(a) - frame.position
	var end: Vector2 = ApartmentWorld.iso(b) - frame.position
	var glass: PackedVector2Array = PackedVector2Array([start - Vector2(0, 45), end - Vector2(0, 45), end - Vector2(0, 135), start - Vector2(0, 135)])
	w.polygon(frame, glass, Color("455e65"))
	w.line(frame, PackedVector2Array([glass[0], glass[1], glass[2], glass[3], glass[0]]), Color("9a9b86"), 6)
	var mid: Vector2 = (start + end) * 0.5
	w.line(frame, PackedVector2Array([mid - Vector2(0, 45), mid - Vector2(0, 135)]), Color("9a9b86"), 5)
	for edge: float in [0.0, 0.88]:
		var from: Vector2 = start.lerp(end, edge)
		var to: Vector2 = start.lerp(end, edge + 0.13)
		w.polygon(frame, PackedVector2Array([from - Vector2(0, 20), to - Vector2(0, 23), to - Vector2(0, 151), from - Vector2(0, 151)]), Color("626b5a"))
		for i: int in 3:
			var fold: Vector2 = from.lerp(to, (i + 0.5) / 3.0)
			w.line(frame, PackedVector2Array([fold - Vector2(0, 25), fold - Vector2(0, 149)]), Color("4e584b"), 2)
	for i: int in 12:
		var rain: Vector2 = start.lerp(end, 0.16 + (i % 9) * 0.075) - Vector2(0, 60 + (i % 4) * 15)
		w.line(frame, PackedVector2Array([rain, rain + Vector2(2, 8)]), Color(0.65, 0.75, 0.73, 0.25), 1)

static func mount(w: ApartmentWorld, logical: Vector2) -> Node2D:
	var requested: Vector2 = ApartmentWorld.iso(logical)
	var foot: Vector2 = requested
	var direction: Vector2 = Vector2.RIGHT
	var nearest: float = INF
	for segment: Vector4 in w.walls:
		var a: Vector2 = Vector2(segment.x, segment.y)
		var b: Vector2 = Vector2(segment.z, segment.w)
		var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(requested, a, b)
		if candidate.distance_to(requested) < nearest:
			nearest = candidate.distance_to(requested)
			foot = candidate
			direction = (b - a).normalized()
	if direction.x < 0: direction = -direction
	var result: Node2D = Node2D.new()
	result.transform = Transform2D(direction, Vector2.DOWN, foot)
	result.z_index = 1
	result.set_meta("wall_mounted", true)
	w.add_child(result)
	return result
