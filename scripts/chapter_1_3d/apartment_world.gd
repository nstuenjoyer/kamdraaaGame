class_name ApartmentWorld3D
extends Node3D

const Layout: GDScript = preload("res://scripts/chapter_1_3d/layout.gd")
const SURFACE: Shader = preload("res://shaders/psx_surface.gdshader")
var interactables: Dictionary = {}
var rooms: Dictionary = {}
var doors: Array[StaticBody3D] = []
var door_links: Array[NavigationLink3D] = []
var lamps: Array[OmniLight3D] = []
var walls: Array[MeshInstance3D] = []
var architectural_trim: Array[MeshInstance3D] = []
var wall_attachments: Array[MeshInstance3D] = []
var material_cache: Dictionary = {}
var wall_pieces: Dictionary = {}
var trim_pieces: Dictionary = {}
var window_parts: Array[MeshInstance3D] = []
var current_floor: int = -1
var current_room: String = ""
var ambient_sources: Array[AudioStreamPlayer3D] = []
var occlusion: RefCounted = preload("res://scripts/chapter_1_3d/view_occlusion.gd").new()
var navigation: NavigationRegion3D

func material(kind: String, color: Color, uv_scale: Vector2 = Vector2.ONE) -> ShaderMaterial:
	var key: String = kind + color.to_html() + str(uv_scale)
	if material_cache.has(key): return material_cache[key]
	var image: Image = Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for y: int in 128:
		for x: int in 128:
			var shade: float = rng.randf_range(0.82, 1.06)
			if kind == "wood":
				shade *= 0.86 + 0.14 * sin(float(x) * 0.72 + sin(float(y) * 0.11))
				if x % 32 < 1 or (y + (x / 32) * 43) % 96 < 1: shade *= 0.48
			elif kind == "tile":
				if x % 32 < 2 or y % 32 < 2: shade *= 0.40
			elif kind == "fabric": shade *= 0.86 if (x + y) % 3 == 0 else 1.0
			elif kind == "rug":
				var border: int = mini(mini(x, 127 - x), mini(y, 127 - y))
				if border < 4 or (border > 10 and border < 14): shade *= 0.30
				elif (absi(x - 64) + absi(y - 64)) % 24 < 4: shade *= 1.35
				else: shade *= 0.60
			elif kind == "wall": shade *= 0.92 + 0.08 * sin(float(y) * 0.07)
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("albedo_texture", ImageTexture.create_from_image(image))
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("texture_scale", uv_scale)
	material_cache[key] = result
	return result

func box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var trim_key: String = label + str(at) + str(dimensions)
	if label in ["DoorFrame", "DoorLintel", "Skirting"] and trim_pieces.has(trim_key): return trim_pieces[trim_key]
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = label
	mesh.set_meta("part_name", label)
	var cube: BoxMesh = BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	if label in ["DoorFrame", "DoorLintel", "Skirting"]:
		architectural_trim.append(mesh)
		trim_pieces[trim_key] = mesh
	if parent.has_meta("wall_anchor"): window_parts.append(mesh)
	if label in ["GalleryFrame", "GalleryPrint", "PrintedSilhouette", "SconcePlate"]: wall_attachments.append(mesh)
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		mesh.add_child(body)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	return mesh

func build() -> void:
	name = "World"
	for id: String in Layout.ROOMS:
		var room: Node3D = Node3D.new()
		room.name = id
		add_child(room)
		rooms[id] = room
		var row: Array = Layout.ROOMS[id]
		var rect: Rect2 = row[1]
		var c: Vector3 = Layout.center(id)
		var floor_color: Color = Color("786047") if row[3] == "wood" else Color("727d76")
		box(room, "Floor", c - Vector3(0, 0.12, 0), Vector3(rect.size.x, 0.24, rect.size.y), material(row[3], floor_color, rect.size * 0.55), true)
		_build_walls(id, room)
		_furnish(id, room, c)
		if id == "bedroom":
			_bedroom_details(room, c)
			_import_bedroom_kit(room, c)
		elif id == "gallery": _gallery_details(room, c)
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = c + Vector3(0, 2.65, 0)
		lamp.light_color = Color("ffdcb0")
		lamp.omni_range = 5.8
		lamp.light_energy = 0.0
		lamp.shadow_enabled = true
		room.add_child(lamp)
		lamps.append(lamp)
	_link_wall_attachments()
	_build_stairs()
	_build_building_context()
	_build_targets()
	for room: Node in rooms.values(): occlusion.collect(room)
	for child: Node in get_children():
		if child.has_meta("connects"): occlusion.collect(child)
	navigation = NavigationRegion3D.new()
	navigation.name = "Navigation"
	var navmesh: NavigationMesh = NavigationMesh.new()
	navmesh.agent_radius = 0.25
	navmesh.agent_height = 1.8
	navmesh.agent_max_climb = 0.25
	navmesh.agent_max_slope = 42.0
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = 1 | 32
	navigation.navigation_mesh = navmesh
	add_child(navigation)

func _build_walls(id: String, room: Node3D) -> void:
	var row: Array = Layout.ROOMS[id]
	var r: Rect2 = row[1]
	var h: float = float(row[0]) * Layout.FLOOR_HEIGHT
	var edges: Array[Array] = [[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for edge_index: int in 4:
		var a: Vector2 = edges[edge_index][0]
		var b: Vector2 = edges[edge_index][1]
		var length: float = a.distance_to(b)
		var direction: Vector2 = a.direction_to(b)
		var openings: Array[float] = []
		for connection: Array in Layout.CONNECTIONS:
			if id not in connection: continue
			var portal: Vector3 = Layout.portal(connection[0], connection[1])
			var point: Vector2 = Vector2(portal.x, portal.z)
			if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 0.05:
				openings.append((point - a).dot(direction))
		# Outdoor stair landings enter through these openings.
		if id == "hall" and edge_index == 3: openings.append(11.0)
		if id == "gallery" and edge_index == 3: openings.append(1.0)
		if id == "kitchen" and edge_index == 1: openings.append(1.5)
		if id == "winter_garden" and edge_index == 1: openings.append(5.5)
		openings.sort()
		var cursor: float = 0.0
		for opening: float in openings:
			_wall_segment(room, a + direction * cursor, a + direction * (opening - 1.0), h)
			var p: Vector2 = a + direction * opening
			var frame: Material = material("wood", Color("302c2d"))
			for side: float in [-1.0, 1.0]:
				var q: Vector2 = p + direction * (side * 1.0)
				box(room, "DoorFrame", Vector3(q.x, h + 1.22, q.y), Vector3(0.13, 2.44, 0.13), frame)
			var lintel: Vector3 = Vector3(2.18, 0.18, 0.32) if absf(direction.x) > 0.5 else Vector3(0.32, 0.18, 2.18)
			box(room, "DoorLintel", Vector3(p.x, h + 2.45, p.y), lintel, frame)
			cursor = opening + 1.0
		_wall_segment(room, a + direction * cursor, b, h)
	for connection: Array in Layout.CONNECTIONS:
		if connection.size() < 3 or connection[0] != id: continue
		var point: Vector3 = Layout.portal(connection[0], connection[1])
		var door: StaticBody3D = StaticBody3D.new()
		door.name = connection[2]
		door.position = point + Vector3(0, 1.16, 0)
		room.add_child(door)
		var vertical: bool = is_equal_approx(point.x, r.position.x) or is_equal_approx(point.x, r.end.x)
		var size: Vector3 = Vector3(0.18, 2.3, 1.95) if vertical else Vector3(1.95, 2.3, 0.18)
		box(door, "Panel", Vector3.ZERO, size, material("wood", Color("4b3a31")))
		var shape: CollisionShape3D = CollisionShape3D.new()
		var bounds: BoxShape3D = BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		door.add_child(shape)
		door.collision_layer = 1
		doors.append(door)
		var link: NavigationLink3D = NavigationLink3D.new()
		add_child(link)
		var axis: Vector3 = Vector3.RIGHT if vertical else Vector3.BACK
		link.start_position = point - axis * 1.1 + Vector3.UP * 0.35
		link.end_position = point + axis * 1.1 + Vector3.UP * 0.35
		link.enabled = false
		door_links.append(link)

func _wall_segment(room: Node3D, a: Vector2, b: Vector2, height: float) -> void:
	if a.distance_to(b) < 0.02: return
	var direction: Vector2 = a.direction_to(b)
	var length: float = a.distance_to(b)
	var cuts: Array[float] = [0.0, length]
	for row: Array in Layout.ROOMS.values():
		if absf(float(row[0]) * Layout.FLOOR_HEIGHT - height) > 0.1: continue
		var r: Rect2 = row[1]
		for point: Vector2 in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
			var t: float = (point - a).dot(direction)
			if t > 0.01 and t < length - 0.01 and Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 0.01 and t not in cuts: cuts.append(t)
	cuts.sort()
	for i: int in cuts.size() - 1: _unique_wall(room, a + direction * cuts[i], a + direction * cuts[i + 1], height)

func _unique_wall(room: Node3D, a: Vector2, b: Vector2, height: float) -> void:
	var first: Vector2 = a if a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y) else b
	var last: Vector2 = b if first == a else a
	var key: String = str(first.snapped(Vector2.ONE * 0.01)) + str(last.snapped(Vector2.ONE * 0.01)) + str(height)
	if wall_pieces.has(key): return
	wall_pieces[key] = true
	if a.distance_to(b) < 0.02: return
	var middle: Vector2 = (a + b) * 0.5
	var size: Vector3 = Vector3(maxf(absf(a.x - b.x), 0.15), 3.35, maxf(absf(a.y - b.y), 0.15))
	var mat: ShaderMaterial = material("wall", Color("827e73"), Vector2(2, 2)).duplicate() as ShaderMaterial
	var wall: MeshInstance3D = box(room, "Wall", Vector3(middle.x, height + 1.675, middle.y), size, mat, true)
	wall.set_meta("wall_plane", ("z:" + str(snappedf(a.y, 0.01)) if absf(a.x - b.x) > 0.01 else "x:" + str(snappedf(a.x, 0.01))) + ":" + str(height))
	walls.append(wall)
	box(room, "Skirting", Vector3(middle.x, height + 0.12, middle.y), Vector3(size.x + 0.04, 0.24, size.z + 0.04), material("wood", Color("423d35")))
	# Independent shadow caster prevents visual fading from opening the room to light.
	var shadow: MeshInstance3D = box(room, "WallShadow", wall.position, size, material("wall", Color.WHITE))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.set_meta("permanent_shadow", true)

func _build_stairs() -> void:
	# Two real ramps with decorative treads; no teleporting between floors.
	_stair("MainStair", Vector3(-14, 0, -4), Vector3(-14, Layout.FLOOR_HEIGHT, 5), "hall", "gallery")
	_stair("ServiceStair", Vector3(14, 0, 1.5), Vector3(14, Layout.FLOOR_HEIGHT, 11.5), "kitchen", "winter_garden")

func _stair(label: String, start: Vector3, finish: Vector3, lower: String, upper: String) -> void:
	var root: Node3D = Node3D.new()
	root.name = label
	add_child(root)
	var run: float = finish.z - start.z
	var rise: float = finish.y - start.y
	var ramp: MeshInstance3D = box(root, "Ramp", (start + finish) * 0.5 - Vector3(0, 0.10, 0), Vector3(2.0, 0.2, sqrt(run * run + rise * rise)), material("wood", Color("544a3c")), true)
	ramp.rotation.x = -atan2(rise, run)
	# Off-mesh links provide a precise centreline. Recast only bakes landings,
	# avoiding diagonal shortcuts across a sloped ramp's exposed corners.
	(ramp.get_child(0) as StaticBody3D).collision_layer = 8 | 16
	for i: int in 24:
		var t: float = float(i) / 24.0
		var p: Vector3 = start.lerp(finish, t) + Vector3(0, -0.05, run / 48.0)
		box(root, "Tread", p, Vector3(2.0, 0.10, run / 24.0), material("wood", Color("6b5946")))
	for end: Vector3 in [start, finish]:
		var landing_center: Vector3 = end + (Vector3(0, 0, 1) if end == finish else Vector3.ZERO)
		var inner_x: float = -11.2 if start.x < 0 else 11.2
		box(root, "Landing", Vector3((end.x + inner_x) * 0.5, end.y - 0.12, landing_center.z), Vector3(absf(end.x - inner_x) + 2.0, 0.24, 2.0), material("wood", Color("645342")), true)
		for side: float in [-1.0, 1.0]:
			box(root, "LandingRail", Vector3(end.x + side, end.y + 0.60, end.z), Vector3(0.08, 1.2, 0.08), material("metal", Color("33383a")))
		var doorway: NavigationLink3D = NavigationLink3D.new()
		root.add_child(doorway)
		var doorway_z: float = landing_center.z - (0.65 if end == start else 0.0)
		doorway.start_position = Vector3(inner_x, end.y + 0.35, doorway_z)
		doorway.end_position = Vector3(end.x, end.y + 0.35, doorway_z)
	for side: float in [-1.0, 1.0]:
		var rail: MeshInstance3D = box(root, "Handrail", (start + finish) * 0.5 + Vector3(side, 1.0, 0), Vector3(0.07, 0.07, sqrt(run * run + rise * rise)), material("metal", Color("353737")))
		rail.rotation.x = ramp.rotation.x
		var guard: StaticBody3D = _guard(root, (start + finish) * 0.5 + Vector3(side, 0.55, 0), Vector3(0.08, 1.1, sqrt(run * run + rise * rise)))
		guard.rotation.x = ramp.rotation.x
		for n: int in 10:
			box(root, "Baluster", start.lerp(finish, float(n) / 9.0) + Vector3(side, 0.52, 0), Vector3(0.05, 1.04, 0.05), material("metal", Color("353737")))
	var outside: float = -1 if start.x < 0 else 1
	for end: Vector3 in [start, finish]:
		var z: float = end.z + (1 if end == finish else 0)
		_guard(root, Vector3(end.x + outside, end.y + 0.55, z), Vector3(0.08, 1.1, 2))
		_guard(root, Vector3(end.x - outside * 0.5, end.y + 0.55, z + (1 if end == finish else -1)), Vector3(3, 1.1, 0.08))
		_guard(root, Vector3(end.x - outside * 1.5, end.y + 0.55, z + (-1 if end == finish else 1)), Vector3(1, 1.1, 0.08))
	root.set_meta("connects", [lower, upper])
	# Explicit centreline traversal avoids cutting across railing corners when
	# Recast separates the narrow landing polygons. Actors still walk the ramp.
	var link: NavigationLink3D = NavigationLink3D.new()
	root.add_child(link)
	link.start_position = start + Vector3(0, 0.35, -0.65)
	link.end_position = finish + Vector3(0, 0.35, 0.7)

func _guard(root: Node3D, p: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	# Railings stop bodies but do not act as opaque walls or walkable nav surfaces.
	body.collision_layer = 8
	body.position = p
	root.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	# Separate bake-only proxy: ramp physics use layer 8 too, while Recast
	# must see railing obstructions without treating the ramp as a shortcut.
	var nav_proxy: StaticBody3D = StaticBody3D.new()
	nav_proxy.collision_layer = 32
	body.add_child(nav_proxy)
	var nav_shape: CollisionShape3D = CollisionShape3D.new()
	nav_shape.shape = shape
	nav_proxy.add_child(nav_shape)
	return body

func _furnish(id: String, root: Node3D, c: Vector3) -> void:
	var wood: Material = material("wood", Color("554435"))
	var cloth: Material = material("fabric", Color("535b5a"))
	# Common furnishings are individually legged, with physical footprints.
	match id:
		"bedroom", "guest":
			var p: Vector3 = c + Vector3(-1.0, 0, -0.5)
			box(root, "BedFrame", p + Vector3(0, 0.27, 0), Vector3(2.1, 0.32, 2.9), wood, true)
			box(root, "Mattress", p + Vector3(0, 0.52, 0), Vector3(2.04, 0.28, 2.8), material("fabric", Color("a19b89")))
			box(root, "Blanket", p + Vector3(0, 0.70, 0.4), Vector3(2.10, 0.16, 1.9), material("fabric", Color("59676a")))
			box(root, "Headboard", p + Vector3(0, 0.85, -1.44), Vector3(2.2, 1.2, 0.12), wood, true)
			for x: float in [-0.52, 0.52]:
				var pillow: MeshInstance3D = box(root, "Pillow", p + Vector3(x, 0.77, -0.94), Vector3(0.85, 0.20, 0.52), material("fabric", Color("bab4a3")))
				pillow.rotation.y = x * 0.10
			_table(root, c + Vector3(1.1, 0, -1.5), Vector2(0.85, 0.65), wood)
			box(root, "Rug", c + Vector3(0.4, 0.015, 1.1), Vector3(3.8, 0.025, 2.1), material("rug", Color("95654b")))
			var room_rect: Rect2 = Layout.ROOMS[id][1]
			_window(root, c + Vector3(-1, 1.75, -room_rect.size.y * 0.5 + 0.08))
		"living":
			box(root, "SofaBase", c + Vector3(-0.6, 0.4, -1.7), Vector3(3.2, 0.65, 1.15), cloth, true)
			box(root, "SofaBack", c + Vector3(-0.6, 0.90, -2.2), Vector3(3.2, 0.85, 0.24), cloth, true)
			for x: float in [-2.1, 0.9]: box(root, "SofaArm", c + Vector3(x, 0.7, -1.7), Vector3(0.24, 0.6, 1.25), cloth)
			_table(root, c + Vector3(0, 0, 0.6), Vector2(2.3, 1.0), wood)
			box(root, "Rug", c + Vector3(0, 0.015, 0.5), Vector3(4.5, 0.02, 3.2), material("fabric", Color("735044"), Vector2(3, 3)))
			_shelf(root, c + Vector3(2.7, 0, -2.2))
		"dining":
			_table(root, c, Vector2(2.7, 1.6), wood)
			for x: float in [-1.8, 1.8]:
				box(root, "ChairSeat", c + Vector3(x, 0.48, 0), Vector3(0.65, 0.14, 0.7), wood, true)
				box(root, "ChairBack", c + Vector3(x, 0.95, -0.3), Vector3(0.65, 0.8, 0.1), wood)
			for x: float in [-0.7, 0.7]: box(root, "Plate", c + Vector3(x, 0.91, 0.25), Vector3(0.36, 0.025, 0.36), material("tile", Color("b9b9a6")))
		"kitchen":
			for x: float in [-2.4, -1.2, 0.0, 1.2]:
				box(root, "KitchenCabinet", c + Vector3(x, 0.47, -2.8), Vector3(1.14, 0.94, 0.62), material("wood", Color("69705f")), true)
				box(root, "Counter", c + Vector3(x, 0.98, -2.8), Vector3(1.2, 0.08, 0.7), material("tile", Color("92988a")))
				box(root, "Handle", c + Vector3(x, 0.76, -2.46), Vector3(0.22, 0.04, 0.05), material("metal", Color("c1b386")))
			box(root, "Fridge", c + Vector3(2.5, 0.95, -2.5), Vector3(0.9, 1.9, 0.8), material("metal", Color("8b9284")), true)
		"study":
			_table(root, c + Vector3(0, 0, -1), Vector2(2.5, 1.1), wood)
			_shelf(root, c + Vector3(-2.6, 0, 0))
			box(root, "FilingCabinet", c + Vector3(2.2, 0.72, 0.5), Vector3(1.1, 1.44, 0.6), material("metal", Color("62675d")), true)
			for y: float in [0.3, 0.7, 1.1]: box(root, "DrawerHandle", c + Vector3(2.2, y, 0.82), Vector3(0.3, 0.05, 0.06), material("metal", Color("b5a67e")))
		"bathroom":
			box(root, "Bath", c + Vector3(-1.7, 0.45, 0), Vector3(1.2, 0.9, 2.2), material("tile", Color("9aa8a2")), true)
			box(root, "Water", c + Vector3(-1.7, 0.91, 0), Vector3(0.9, 0.01, 1.8), material("tile", Color("374c4c")))
			box(root, "Basin", c + Vector3(1.8, 0.85, -1.5), Vector3(0.9, 0.2, 0.65), material("tile", Color("b0b7aa")), true)
		"utility":
			box(root, "Washer", c + Vector3(3, 0.5, -2), Vector3(1, 1, 0.8), material("metal", Color("a0a394")), true)
			_table(root, c + Vector3(-2.0, 0, 1.5), Vector2(2.4, 0.9), wood)
		"winter_garden":
			_window(root, c + Vector3(0, 1.75, 3.42))
			for x: float in [-2.6, 0, 2.6]:
				box(root, "Planter", c + Vector3(x, 0.3, -1), Vector3(0.7, 0.6, 0.7), material("tile", Color("795345")), true)
				box(root, "Leaves", c + Vector3(x, 1.05, -1), Vector3(0.9, 1, 0.7), material("fabric", Color("3d5145")))
		"storage", "dressing":
			_shelf(root, c + Vector3(-2.4, 0, -1))
			box(root, "Wardrobe", c + Vector3(2, 1.15, -1.8), Vector3(1.8, 2.3, 0.65), wood, true)
		_:
			_table(root, c + Vector3(1.2, 0, -1.5), Vector2(1.8, 0.55), wood)

func _table(root: Node3D, p: Vector3, size: Vector2, mat: Material) -> void:
	box(root, "TableTop", p + Vector3(0, 0.84, 0), Vector3(size.x, 0.12, size.y), mat, true)
	for x: float in [-1, 1]:
		for z: float in [-1, 1]: box(root, "TableLeg", p + Vector3(x * (size.x * 0.5 - 0.1), 0.4, z * (size.y * 0.5 - 0.1)), Vector3(0.10, 0.8, 0.10), mat)

func _shelf(root: Node3D, p: Vector3) -> void:
	var wood: Material = material("wood", Color("4c4033"))
	box(root, "BookcaseBack", p + Vector3(0, 1.1, -0.17), Vector3(1.7, 2.2, 0.12), wood, true)
	for y: float in [0.1, 0.6, 1.1, 1.6, 2.1]:
		box(root, "Shelf", p + Vector3(0, y, 0), Vector3(1.8, 0.08, 0.5), wood)
		for n: int in 8:
			box(root, "Book", p + Vector3(-0.7 + n * 0.19, y + 0.22, 0), Vector3(0.13, 0.35, 0.32), material("fabric", Color.from_hsv(float(n % 4) * 0.15, 0.27, 0.32 + float(n % 3) * 0.1)))

func _window(room: Node3D, p: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "WindowAssembly"
	root.set_meta("wall_anchor", p)
	room.add_child(root)
	root.position = p
	if p.z > Layout.center(str(room.name)).z: root.rotation.y = PI
	p = Vector3.ZERO
	box(root, "WindowRecess", p, Vector3(2.7, 1.8, 0.25), material("metal", Color("253e50")))
	box(root, "WindowSill", p + Vector3(0, -0.95, 0.16), Vector3(3.0, 0.12, 0.48), material("wood", Color("60574a")))
	for x: float in [-1.4, 0, 1.4]: box(root, "WindowFrame", p + Vector3(x, 0, 0.16), Vector3(0.09, 1.95, 0.12), material("wood", Color("514e44")))
	for x: float in [-1.65, 1.65]: box(root, "Curtain", p + Vector3(x, -0.15, 0.3), Vector3(0.45, 2.6, 0.18), material("fabric", Color("51484a")))
	var light: SpotLight3D = SpotLight3D.new()
	root.add_child(light)
	light.position = p + Vector3(0, 0.5, 0.7)
	light.rotation_degrees = Vector3(-38, 180, 0)
	light.light_color = Color("91b5d2")
	light.light_energy = 5.0
	light.spot_range = 9.0
	light.spot_angle = 52.0
	light.shadow_enabled = true
	var rain: GPUParticles3D = GPUParticles3D.new()
	rain.name = "RainOnGlass"
	root.add_child(rain)
	rain.position = p + Vector3(0, 0, 0.20)
	rain.amount = 100
	rain.lifetime = 1.3
	rain.preprocess = 1.3
	rain.visibility_aabb = AABB(Vector3(-1.4, -1.3, -0.1), Vector3(2.8, 2.6, 0.3))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(1.3, 0.7, 0.01)
	process.direction = Vector3(0.07, -1, 0)
	process.spread = 1
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.75
	process.gravity = Vector3(0, -0.2, 0)
	rain.process_material = process
	var drop: BoxMesh = BoxMesh.new()
	drop.size = Vector3(0.012, 0.10, 0.006)
	var wet: StandardMaterial3D = StandardMaterial3D.new()
	wet.albedo_color = Color("a4c4d4")
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = wet
	rain.draw_pass_1 = drop
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.stream = preload("res://assets/audio/menu_rain.wav")
	audio.unit_size = 3.5
	audio.max_distance = 16
	audio.volume_db = -19
	audio.bus = "SFX"
	audio.position = p
	root.add_child(audio)
	ambient_sources.append(audio)
	audio.play()

func cylinder(root: Node3D, label: String, at: Vector3, bottom: float, top: float, height: float, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label
	node.set_meta("part_name", label)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	root.add_child(node)
	if label == "SconceShade": wall_attachments.append(node)
	return node

func _import_bedroom_kit(root: Node3D, c: Vector3) -> void:
	var path: String = "res://assets/models/environment/apartment_psx/bedroom_kit.glb"
	if not ResourceLoader.exists(path): return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null: return
	var replace: Array[String] = ["BedFrame", "Mattress", "Blanket", "Headboard", "Pillow", "BedPost", "BedFootRail", "BlanketFold", "Chest", "Drawer", "Pull", "MirrorFrame", "MirrorGlass", "LampBase", "LampStem", "LampShade", "TableTop", "TableLeg"]
	for child: Node in root.get_children():
		if child is MeshInstance3D and str(child.get_meta("part_name", "")) in replace:
			(child as MeshInstance3D).visible = false
	var offsets: Dictionary = {"Bed": Vector3(-1, 0, -0.5), "Nightstand": Vector3(1.1, 0, -1.5), "Lamp": Vector3(1.05, 0.94, -1.6), "Chest": Vector3(2.65, 0, 1)}
	for piece: String in offsets:
		var kit: Node3D = packed.instantiate() as Node3D
		var object: Node3D = kit.find_child(piece, true, false) as Node3D
		if object != null:
			object.get_parent().remove_child(object)
			root.add_child(object)
			object.position = c + offsets[piece]
			_convert_kit_materials(object)
		kit.free()

func _convert_kit_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var source: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		if source != null:
			var colors: Dictionary = {"DarkWalnut": Color("493523"), "WornEdges": Color("715338"), "AgedLinen": Color("aaa08a"), "SlateBlanket": Color("596d72"), "TarnishedBrass": Color("a18046"), "Recesses": Color("181816"), "WarmLampshade": Color("b7a07a"), "SmokedMirrorPlaceholder": Color("53656c")}
			var kind: String = "fabric" if source.resource_name in ["SlateBlanket", "AgedLinen", "WarmLampshade"] else "wood"
			mesh.material_override = material(kind, colors.get(source.resource_name, source.albedo_color))
	for child: Node in node.get_children(): _convert_kit_materials(child)

func _bedroom_details(root: Node3D, c: Vector3) -> void:
	var dark_wood: Material = material("wood", Color("4e3829"))
	var brass: Material = material("metal", Color("af8c50"))
	var fabric: Material = material("fabric", Color("a18c70"))
	# Bed posts and folds give the silhouette depth without tiny bevels.
	for x: float in [-2.1, 0.1]:
		for z: float in [-1.9, 0.95]:
			box(root, "BedPost", c + Vector3(x, 0.43, z), Vector3(0.15, 0.86, 0.15), dark_wood)
	box(root, "BedFootRail", c + Vector3(-1, 0.4, 0.96), Vector3(2.2, 0.23, 0.14), dark_wood)
	for n: int in 6:
		var fold: MeshInstance3D = box(root, "BlanketFold", c + Vector3(-1.85 + n * 0.33, 0.80 + (n % 2) * 0.015, 0.16), Vector3(0.08, 0.035, 1.5), material("fabric", Color("646d6b")))
		fold.rotation.y = float(n - 3) * 0.035
	# Small chest, recessed drawers, metal pulls, mirror and a shaded lamp.
	box(root, "Chest", c + Vector3(2.65, 0.63, 1.0), Vector3(1.3, 1.26, 0.72), dark_wood, true)
	for y: float in [0.27, 0.65, 1.03]:
		box(root, "Drawer", c + Vector3(2.65, y, 1.39), Vector3(1.14, 0.30, 0.06), material("wood", Color("66503c")))
		for x: float in [2.3, 3]: box(root, "Pull", c + Vector3(x, y, 1.44), Vector3(0.12, 0.035, 0.04), brass)
	box(root, "MirrorFrame", c + Vector3(2.65, 2.15, 0.72), Vector3(1.3, 1.55, 0.10), dark_wood)
	box(root, "MirrorGlass", c + Vector3(2.65, 2.15, 0.78), Vector3(1.12, 1.35, 0.025), material("metal", Color("65757a")))
	var lamp_position: Vector3 = c + Vector3(1.05, 0.96, -1.6)
	cylinder(root, "LampBase", lamp_position, 0.16, 0.16, 0.045, brass)
	cylinder(root, "LampStem", lamp_position + Vector3(0, 0.23, 0), 0.025, 0.025, 0.44, brass)
	cylinder(root, "LampShade", lamp_position + Vector3(0, 0.49, 0), 0.26, 0.15, 0.32, fabric)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = lamp_position + Vector3(0, 0.38, 0.02)
	lamp.light_color = Color("ffc584")
	lamp.light_energy = 0.85
	lamp.omni_range = 3.3
	lamp.shadow_enabled = true
	root.add_child(lamp)
	# The small bedside lamp is battery powered; room power remains optional.
	for n: int in 9:
		var paper: MeshInstance3D = box(root, "ScatteredPaper", c + Vector3(0.7 + float(n % 3) * 0.37, 0.04, 1.6 + float(n / 3) * 0.36), Vector3(0.25, 0.007, 0.34), material("wall", Color("b2a78b")))
		paper.rotation.y = sin(float(n) * 4.1) * 0.8
		for line: int in 4: box(paper, "Ink", Vector3(0, 0.005, -0.09 + line * 0.045), Vector3(0.14, 0.002, 0.007), material("wall", Color("57534a")))
	for n: int in 8:
		box(root, "RadiatorFin", c + Vector3(-0.9 + n * 0.18, 0.42, -3.16), Vector3(0.12, 0.7, 0.22), material("metal", Color("777f76")))
	for side: float in [-1, 1]:
		for n: int in 5:
			box(root, "CurtainFold", c + Vector3(-1 + side * (1.45 + n * 0.09), 1.55, -3.05 + (n % 2) * 0.08), Vector3(0.10, 2.4, 0.09), material("fabric", Color("5d4d47")))

func target(id: String, room: String, offset: Vector3, title: String, kind: String = "wood") -> void:
	var node: Node3D = Node3D.new()
	node.name = id
	(rooms[room] as Node3D).add_child(node)
	node.position = Layout.center(room) + offset
	node.set_meta("title", title)
	node.set_meta("kind", kind)
	node.set_meta("room", room)
	interactables[id] = node
	var marker: MeshInstance3D = box(node, "Object", Vector3.ZERO, Vector3(0.15, 0.06, 0.18), material("metal", Color("b6a87c")))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_targets() -> void:
	var entries: Array[Array] = [
		["bed", "bedroom", Vector3(-1, 0.7, 1.05), "Осмотреть кровать"],
		["pills", "bedroom", Vector3(0.3, 0.18, 1.4), "Подобрать блистер"],
		["flashlight", "bedroom", Vector3(1.1, 0.95, -1.5), "Фонарик"],
		["phone", "bedroom", Vector3(1.35, 0.95, -1.25), "Мобильный телефон"],
		["charger", "bedroom", Vector3(1.45, 0.9, -1.55), "Подключить телефон"],
		["bedside", "bedroom", Vector3(2.65, 1.3, 0.9), "Листок у кровати"],
		["jacket", "bedroom", Vector3(2.7, 1.0, 2.4), "Проверить карманы куртки"],
		["key_rack", "kitchen", Vector3(-2, 1.2, -2.4), "Кухонная ключница"],
		["key_cabinet", "study", Vector3(2.2, 1.2, 0.9), "Картотека"],
		["desk_note", "study", Vector3(0, 0.95, -0.7), "Записка на столе"],
		["wall_clock", "living", Vector3(2.5, 1.2, -1.8), "Часы · 21:40"],
		["microwave", "kitchen", Vector3(0, 1.1, -2.4), "Записка об отключении"],
		["service_log", "utility", Vector3(-1.4, 0.95, 1.5), "Журнал отключений"],
		["sofa_search", "living", Vector3(-0.6, 0.75, -1), "Осмотреть подушки дивана"],
		["exit", "hall", Vector3(-2.5, 1, -5.7), "Входная дверь"],
		["vase", "living", Vector3(2, 0.1, 1.4), "Разбитая ваза"],
		["cupboard_key", "living", Vector3(2.2, 0.1, 1.5), "Ключ под осколками"],
		["cupboard", "hall", Vector3(2, 1, -3.5), "Шкаф в прихожей"],
		["screwdriver", "utility", Vector3(-2.4, 0.95, 1.5), "Отвёртка"],
		["fuse", "kitchen", Vector3(1.2, 1.1, -2.4), "Предохранитель"],
		["fusebox", "storage", Vector3(1.3, 1.4, 2.5), "Электрощиток"],
		["throwable", "living", Vector3(0.7, 0.96, 0.6), "Целая ваза"],
		["rope", "dressing", Vector3(-2.2, 1.3, -0.6), "Бельевой шнур"],
		["heavy", "kitchen", Vector3(-1.2, 1.1, -2.4), "Чугунная сковорода"],
		["bathroom", "bathroom", Vector3(1.8, 1.4, -1.3), "Надпись на зеркале"],
		["hall_mirror", "hall", Vector3(2, 1.4, 3), "Зеркало прихожей"],
		["bath_note", "bathroom", Vector3(1.8, 0.9, -0.6), "Записка под полотенцем"],
		["hide_sofa", "living", Vector3(-1, 0.2, -2.7), "Укрыться за диваном"],
		["hide_bath", "bathroom", Vector3(-2.7, 0.2, 0), "Укрыться за ванной"],
		["hide_wardrobe", "dressing", Vector3(2, 0.2, -0.8), "Укрыться у гардероба"],
		["tap", "bathroom", Vector3(1.7, 1, -1.6), "Закрыть кран"],
		["books", "study", Vector3(-2.6, 1, 0.4), "Книжная полка"],
		["records", "living", Vector3(2.5, 1.1, -2), "Проигрыватель"],
		["photo", "guest", Vector3(2, 1.0, 1), "Старая фотография"],
		["laundry", "utility", Vector3(3, 1.0, -1.5), "Стиральная машина"],
		["pantry", "storage", Vector3(-2, 1, -0.5), "Осмотреть коробки"],
		["meal", "dining", Vector3(0, 1, 0), "Два прибора"],
		["coat_hook", "hall", Vector3(2, 1, 0), "Пустые крючки"],
		["garden_note", "winter_garden", Vector3(0, 1, -0.8), "Следы на подоконнике"],
		["guest_note", "guest", Vector3(2, 0.8, 2), "Чужой чемодан"],
		["coat_trap", "hall", Vector3(0, 0.2, -4.5), "Толкнуть вешалку"]
	]
	for entry: Array in entries: target(entry[0], entry[1], entry[2], entry[3])
	for i: int in Layout.CONNECTIONS.size():
		var connection: Array = Layout.CONNECTIONS[i]
		if connection.size() < 3: continue
		var portal: Vector3 = Layout.portal(connection[0], connection[1])
		target(connection[2], connection[0], portal - Layout.center(connection[0]) + Vector3(0, 1, 0), "Открыть кабинет")

func set_study_open(value: bool) -> void:
	for door: StaticBody3D in doors:
		door.visible = not value
		door.collision_layer = 0 if value else 1
	for link: NavigationLink3D in door_links: link.enabled = value

func clear_line(a: Vector3, b: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1 | 16)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update_visibility(player: Vector3, camera: Camera3D, view_room: String = "", delta: float = 0.016667) -> void:
	var active_room: String = view_room if Layout.ROOMS.has(view_room) else Layout.room_at(player)
	var floor_index: int = int(Layout.ROOMS[active_room][0])
	if current_floor != floor_index:
		current_floor = floor_index
		for id: String in rooms:
			_set_floor_meshes(rooms[id], int(Layout.ROOMS[id][0]) > floor_index)
		for child: Node in get_children():
			if child.has_meta("connects"): _set_floor_meshes(child, false)
	current_room = active_room
	occlusion.update(camera, player, delta)

func _set_floor_meshes(node: Node, shadow_only: bool) -> void:
	if node is GPUParticles3D: (node as GPUParticles3D).visible = not shadow_only
	if node is MeshInstance3D and not node.get_meta("permanent_shadow", false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if shadow_only else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child: Node in node.get_children(): _set_floor_meshes(child, shadow_only)

func update_audio(listener: Vector3) -> void:
	for source: AudioStreamPlayer3D in ambient_sources:
		source.volume_db = -19.0 if clear_line(listener, source.global_position) else -32.0

func _build_building_context() -> void:
	# Visual architecture only: these masses cannot change navigation or saves.
	var root: Node3D = Node3D.new()
	root.name = "BuildingContext"
	add_child(root)
	box(root, "Foundation", Vector3(0, -1.55, 3.5), Vector3(24.3, 3.0, 21.3), material("wall", Color("3d4140"), Vector2(12, 5)))
	box(root, "Street", Vector3(0, -3.12, 0), Vector3(120, 0.2, 120), material("tile", Color("252f35"), Vector2(30, 30)))
	box(root, "Pavement", Vector3(0, -2.98, 3.5), Vector3(34, 0.16, 31), material("tile", Color("444e51"), Vector2(15, 15)))
	for x: float in [-12.12, 12.12]:
		box(root, "FloorBand", Vector3(x, -0.15, 3.5), Vector3(0.22, 0.3, 21.5), material("wall", Color("59594e")))
	var window_mat: StandardMaterial3D = StandardMaterial3D.new()
	window_mat.albedo_color = Color("82714f")
	window_mat.emission_enabled = true
	window_mat.emission = Color("82714f")
	window_mat.emission_energy_multiplier = 0.5
	for n: int in 7:
		var x: float = -39 + n * 13
		var height: float = 10 + (n % 3) * 4
		box(root, "NeighbourBuilding", Vector3(x, height * 0.5 - 3, -30), Vector3(10, height, 10), material("wall", Color("26333e"), Vector2(5, 5)))
		for row: int in 4:
			for column: int in 3:
				if (row + column + n) % 3 == 0: continue
				box(root, "DistantWindow", Vector3(x - 3 + column * 3, row * 2.5, -24.94), Vector3(0.75, 1.1, 0.02), window_mat)

func _gallery_details(root: Node3D, c: Vector3) -> void:
	box(root, "GalleryRunner", c + Vector3(0, 0.022, 0.3), Vector3(12.4, 0.025, 1.4), material("rug", Color("77523f"), Vector2(4, 1)))
	var frame: Material = material("wood", Color("4d3829"))
	var brass: Material = material("metal", Color("a28b59"))
	for x: float in [-6.4, -0.2, 5.2]:
		var p: Vector3 = c + Vector3(x, 1.75, -3.32)
		box(root, "GalleryFrame", p, Vector3(1.35, 1.15, 0.09), frame)
		box(root, "GalleryPrint", p + Vector3(0, 0, 0.055), Vector3(1.17, 0.96, 0.012), material("fabric", Color("6d756a")))
		# Abstract skyline in the old prints, built from broad pixel-like masses.
		for n: int in 5:
			box(root, "PrintedSilhouette", p + Vector3(-0.44 + n * 0.22, -0.12, 0.067), Vector3(0.18, 0.24 + float(n % 3) * 0.11, 0.006), material("wall", Color("3a4546")))
	for x: float in [-3.2, 3.0]:
		var p: Vector3 = c + Vector3(x, 2.0, -3.25)
		box(root, "SconcePlate", p, Vector3(0.15, 0.4, 0.09), brass)
		cylinder(root, "SconceShade", p + Vector3(0, 0.12, 0.16), 0.15, 0.1, 0.24, material("fabric", Color("b7a587")))
		var light: OmniLight3D = OmniLight3D.new()
		root.add_child(light)
		light.position = p + Vector3(0, 0.12, 0.30)
		light.omni_range = 2.5
		light.light_color = Color("ffd4a1")
		light.light_energy = 0
		lamps.append(light)

func _link_wall_attachments() -> void:
	for attachment: MeshInstance3D in wall_attachments + window_parts + architectural_trim:
		var point: Vector3 = attachment.position
		if attachment.get_parent().has_meta("wall_anchor"): point = attachment.get_parent().get_meta("wall_anchor")
		var nearest: MeshInstance3D = null
		var distance: float = 0.5
		for wall: MeshInstance3D in walls:
			var bounds: AABB = wall.get_aabb()
			var local: Vector3 = wall.to_local(point)
			var d: float = local.distance_to(local.clamp(bounds.position, bounds.end))
			if d < distance:
				nearest = wall
				distance = d
		if nearest != null: attachment.set_meta("support_mesh", nearest)
