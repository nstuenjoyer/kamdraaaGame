class_name ApartmentDepthSlicer
extends RefCounted

# Each small mesh is sorted at its ground contact, not at the centre of a large prop.
# This is the painter's-algorithm equivalent of a ground-depth buffer for raised 2D art.
const STRIP: float = 12.0
const PROP_SHADER: Shader = preload("res://shaders/prop_depth.gdshader")

static func sprite(world: Node2D, object: Node2D, texture: Texture2D, height: float) -> void:
	var image: Image = texture.get_image()
	var used: Rect2i = image.get_used_rect()
	var rect: Rect2 = object.get_meta("footprint")
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		points.append(Vector2(point.x - point.y, (point.x + point.y) * 0.5))
	var left: float = INF
	var right: float = -INF
	var back: float = INF
	var front: float = -INF
	for point: Vector2 in points:
		left = minf(left, point.x)
		right = maxf(right, point.x)
		back = minf(back, point.y)
		front = maxf(front, point.y)
	var scale_value: float = (right - left) / used.size.x
	var art_height: float = (front - back) + maxf(65.0, height * 2.0)
	var origin: Vector2 = Vector2(left, front - art_height)
	for child: Node in world.get_children():
		if child.has_meta("prop_id") and str(child.get_meta("prop_id")) == str(object.name): child.visible = false
	for row: int in range(floori(back / STRIP), ceili(front / STRIP) + 1):
		var node: Node2D = Node2D.new()
		node.position = Vector2(0, (row + 0.5) * STRIP)
		node.set_meta("prop_id", object.name)
		node.set_meta("ground_depth", node.position.y)
		world.add_child(node)
		var art: Sprite2D = Sprite2D.new()
		art.texture = texture
		art.region_enabled = true
		art.region_rect = used
		art.centered = false
		art.scale = Vector2(scale_value, art_height / used.size.y)
		art.position = origin - node.position
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = PROP_SHADER
		shader_material.set_shader_parameter("footprint", points)
		shader_material.set_shader_parameter("lower_depth", row * STRIP)
		shader_material.set_shader_parameter("upper_depth", (row + 1) * STRIP)
		shader_material.set_shader_parameter("prop_height", height)
		art.material = shader_material
		node.add_child(art)

static func clip(vertices: Array[Vector3], boundary: float, keep_above: bool) -> Array[Vector3]:
	var output: Array[Vector3] = []
	if vertices.is_empty(): return output
	var previous: Vector3 = vertices[-1]
	var previous_inside: bool = previous.z >= boundary if keep_above else previous.z <= boundary
	for current: Vector3 in vertices:
		var inside: bool = current.z >= boundary if keep_above else current.z <= boundary
		if inside != previous_inside:
			var ratio: float = (boundary - previous.z) / (current.z - previous.z)
			output.append(previous.lerp(current, ratio))
		if inside: output.append(current)
		previous = current
		previous_inside = inside
	return output

static func polygon(world: Node2D, source: Node2D, points: PackedVector2Array, color: Color, depths: PackedFloat32Array) -> void:
	if points.size() < 3: return
	var vertices: Array[Vector3] = []
	var minimum: float = INF
	var maximum: float = -INF
	for i: int in points.size():
		var pos: Vector2 = source.to_global(points[i])
		vertices.append(Vector3(pos.x, pos.y, depths[i]))
		minimum = minf(minimum, depths[i])
		maximum = maxf(maximum, depths[i])
	var first: int = floori(minimum / STRIP)
	var last: int = floori(maximum / STRIP)
	for row: int in range(first, last + 1):
		var clipped: Array[Vector3] = clip(clip(vertices, row * STRIP, true), (row + 1) * STRIP, false)
		if clipped.size() < 3: continue
		var geometry: PackedVector2Array = PackedVector2Array()
		var origin: Vector2 = Vector2(0, (row + 0.5) * STRIP)
		for vertex: Vector3 in clipped:
			var point: Vector2 = Vector2(vertex.x, vertex.y) - origin
			if geometry.is_empty() or not geometry[-1].is_equal_approx(point): geometry.append(point)
		if geometry.size() > 2 and geometry[0].is_equal_approx(geometry[-1]): geometry.resize(geometry.size() - 1)
		if geometry.size() < 3 or Geometry2D.triangulate_polygon(geometry).is_empty(): continue
		var piece: Polygon2D = Polygon2D.new()
		piece.position = origin
		piece.polygon = geometry
		piece.color = color
		piece.set_meta("prop_id", source.name)
		piece.set_meta("ground_depth", origin.y)
		world.add_child(piece)

static func bake(world: Node2D, object: Node2D) -> void:
	var height: float = object.get_meta("height", 0.0)
	for child: Node in object.get_children():
		if child.has_meta("skip_depth_bake"): continue
		if child is Polygon2D:
			var poly: Polygon2D = child
			var depths: PackedFloat32Array = poly.get_meta("floor_depths", PackedFloat32Array())
			if depths.is_empty():
				for point: Vector2 in poly.polygon: depths.append(object.position.y + point.y + height)
			polygon(world, object, poly.polygon, poly.color, depths)
			poly.visible = false
		elif child is Line2D:
			var stroke: Line2D = child
			for i: int in stroke.points.size() - 1:
				var a: Vector2 = stroke.points[i]
				var b: Vector2 = stroke.points[i + 1]
				var normal: Vector2 = (b - a).normalized().orthogonal() * stroke.width * 0.5
				var points: PackedVector2Array = PackedVector2Array([a + normal, b + normal, b - normal, a - normal])
				var depths: PackedFloat32Array = PackedFloat32Array()
				for point: Vector2 in points: depths.append(object.position.y + point.y + height)
				polygon(world, object, points, stroke.default_color, depths)
			stroke.visible = false
