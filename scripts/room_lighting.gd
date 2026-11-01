extends Node2D

# Shadows describe footprints on the floor. Elevated artwork needs separate
# lighting channels so its pixels are not mistaken for floor behind a wall.
const FLOOR_MASK: int = 1
const BEDROOM_WALL_MASK: int = 2
const STORAGE_WALL_MASK: int = 4
const ACTOR_MASK: int = 8

var _player: CharacterBody2D
var _flashlight: Node2D
var _actor_light: PointLight2D
var _wall_beam: PointLight2D
var _wall_spots: Array[PointLight2D] = []
var _wall_masks: Dictionary = {}
var _room: Node2D
var _sprite: Sprite2D
var _player_label: Label
var _fading_faces: Array[Polygon2D] = []
var _face_alphas: Dictionary = {}

func _ready() -> void:
	var room: Node2D = get_parent() as Node2D
	_room = room
	_player = room.get_node("Player") as CharacterBody2D
	_flashlight = _player.get_node("Flashlight") as Node2D
	var fill_texture: Texture2D = $Room1CeilingLight.texture
	var radial_texture: Texture2D = $DeskLampLight.texture
	for face: Node in room.get_node("Walls").get_children():
		if face is Polygon2D:
			var polygon: Polygon2D = face as Polygon2D
			polygon.light_mask = STORAGE_WALL_MASK if polygon.name.begins_with("Dark") else BEDROOM_WALL_MASK
			_add_wall_cap(polygon)
			if polygon.name == "DarkCorridorRight_Visual":
				_track_foreground_face(polygon)
	for face: Node in room.get_node("FrontWalls").get_children():
		if face is Polygon2D:
			var polygon: Polygon2D = face as Polygon2D
			polygon.light_mask = STORAGE_WALL_MASK if polygon.name.begins_with("Dark") else BEDROOM_WALL_MASK
			_track_foreground_face(polygon)
		elif face is Line2D:
			face.material = _unshaded_material()
	_setup_wall_spots(radial_texture)
	_add_fill("BedroomWallFill", Vector2(590, 220), fill_texture, 5.0, 0.85, Color(0.72, 0.79, 0.92), BEDROOM_WALL_MASK, false)
	_add_fill("StorageWallFill", Vector2(1120, 450), fill_texture, 4.0, 0.55, Color(0.55, 0.65, 0.82), STORAGE_WALL_MASK, false)
	_add_fill("StorageFloorFill", Vector2(1130, 520), fill_texture, 2.8, 0.32, Color(0.50, 0.63, 0.82), FLOOR_MASK, true)
	_sprite = _player.get_node("DashaSprite") as Sprite2D
	_sprite.light_mask = ACTOR_MASK
	_actor_light = _add_fill("CharacterFill", Vector2.ZERO, radial_texture, 1.05, 0.9, Color(0.85, 0.90, 1.0), ACTOR_MASK, false)
	_actor_light.reparent(_player, false)
	_actor_light.position = Vector2(0, -40)
	_player_label = _player.get_node("PlayerLabel") as Label
	_player_label.material = _unshaded_material()
	# Crate/safe fronts are elevated artwork too; their footprint shadows
	# remain on the floor channel, while the visible fronts receive bounce.
	for visual: Node in room.get_node("DarkRoomProps").find_children("*", "Polygon2D", true, false):
		if not "Shadow" in visual.name and not "Bottom" in visual.name:
			visual.light_mask = STORAGE_WALL_MASK
	for label: Node in room.get_node("DarkRoomProps").find_children("*", "Label", true, false):
		label.light_mask = STORAGE_WALL_MASK
	# Wall pixels sit above their physical footprints. Give the flashlight a
	# modest wall-only bounce; floor rays still stop at occluders normally.
	_wall_beam = _add_fill("FlashlightWallBounce", Vector2.ZERO, radial_texture, 2.0, 0.18, Color(0.85, 0.88, 0.95), BEDROOM_WALL_MASK | STORAGE_WALL_MASK, false)
	_wall_beam.reparent(_player, false)
	_wall_beam.position = Vector2(0, -45)
	var corridor: Polygon2D = room.get_node("Floor/DarkRoomFloor") as Polygon2D
	corridor.color = Color(0.17, 0.20, 0.26)
	var ambient: CanvasModulate = room.get_node("CanvasModulate") as CanvasModulate
	ambient.color = Color(0.14, 0.17, 0.23)

func _add_fill(node_name: String, light_position: Vector2, texture: Texture2D, scale_factor: float, energy: float, tint: Color, mask: int, shadows: bool) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.name = node_name
	light.position = light_position
	light.texture = texture
	light.texture_scale = scale_factor
	light.energy = energy
	light.color = tint
	light.range_item_cull_mask = mask
	light.shadow_enabled = shadows
	light.shadow_color = Color(0, 0, 0, 0)
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(light)
	return light

func _unshaded_material() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return material

func _add_wall_cap(face: Polygon2D) -> void:
	var top: PackedVector2Array = face.polygon.slice(face.polygon.size() >> 1)
	var cap: Polygon2D = Polygon2D.new()
	cap.name = "TopCap"
	var vertices: PackedVector2Array = top.duplicate()
	for index: int in range(top.size() - 1, -1, -1):
		vertices.append(top[index] + Vector2(0, -6))
	cap.polygon = vertices
	cap.color = Color(0.29, 0.35, 0.45)
	cap.material = _unshaded_material()
	face.add_child(cap)
	var rim: Line2D = Line2D.new()
	rim.name = "TopRim"
	rim.points = top
	rim.width = 1.4
	rim.default_color = Color(0.50, 0.59, 0.70, 0.85)
	rim.material = _unshaded_material()
	face.add_child(rim)

func _track_foreground_face(face: Polygon2D) -> void:
	_fading_faces.append(face)
	_face_alphas[face] = face.color.a

func _setup_wall_spots(texture: Texture2D) -> void:
	var bit: int = 5
	for collision: Node in _room.get_node("Walls").get_children():
		if not collision is CollisionPolygon2D:
			continue
		var wall_name: String = String(collision.name).trim_suffix("_Collision")
		var face: Polygon2D = _room.get_node_or_null("Walls/" + wall_name + "_Visual") as Polygon2D
		if not face:
			face = _room.get_node_or_null("FrontWalls/" + wall_name + "_FrontVisual") as Polygon2D
		if not face:
			continue
		var mask: int = 1 << bit
		bit += 1
		_wall_masks[collision] = mask
		face.light_mask |= mask
		if wall_name == "WallNW":
			for decoration: Node in _room.get_node("MirrorWithLipstick/VisualRoot").find_children("*", "CanvasItem", true, false):
				decoration.light_mask = face.light_mask
		var cap: Polygon2D = face.get_node_or_null("TopCap") as Polygon2D
		if cap:
			cap.light_mask = face.light_mask
			cap.material = null
	# One continuous spot on the first wall hit by the central beam.
	# Its radius grows with distance; no overlapping lobes from separate rays.
	for index: int in range(1):
		var spot: PointLight2D = _add_fill("WallSpot%d" % index, Vector2.ZERO, texture, 0.6, 1.0, Color(1.0, 0.97, 0.9), 0, false)
		spot.enabled = false
		_wall_spots.append(spot)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_flashlight):
		return
	var offsets: Array[float] = [0.0]
	var space: PhysicsDirectSpaceState2D = _room.get_world_2d().direct_space_state
	for index: int in range(_wall_spots.size()):
		var spot: PointLight2D = _wall_spots[index]
		spot.enabled = false
		if not _flashlight.is_on():
			continue
		var direction: Vector2 = Vector2.RIGHT.rotated(_flashlight.global_rotation + offsets[index])
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_player.global_position, _player.global_position + direction * 520.0)
		query.exclude = [_player.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or hit.collider != _room.get_node("Walls"):
			continue
		var walls: CollisionObject2D = hit.collider as CollisionObject2D
		var owner_id: int = walls.shape_find_owner(int(hit.shape))
		var collision: Object = walls.shape_owner_get_owner(owner_id)
		if not _wall_masks.has(collision):
			continue
		var distance: float = _player.global_position.distance_to(hit.position)
		var radius: float = clampf(42.0 + distance * 0.30, 48.0, 170.0)
		spot.global_position = hit.position - Vector2(0, 45)
		spot.texture_scale = radius / 128.0
		spot.range_item_cull_mask = int(_wall_masks[collision])
		var angular_weight: float = 1.0 - absf(offsets[index]) / 0.85
		spot.energy = 2.0 * angular_weight * pow(1.0 - distance / 540.0, 0.65)
		spot.enabled = true

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var flashlight_on: bool = _flashlight.is_on()
	_wall_beam.enabled = flashlight_on
	_actor_light.energy = 0.9 if flashlight_on else 0.55
	var feet: Vector2 = _player.global_position
	var body_rect: PackedVector2Array = PackedVector2Array([
		feet + Vector2(-24, -88), feet + Vector2(24, -88),
		feet + Vector2(24, 8), feet + Vector2(-24, 8)
	])
	var foreground_overlap: bool = false
	for face: Polygon2D in _fading_faces:
		var world_polygon: PackedVector2Array = face.global_transform * face.polygon
		var overlaps: bool = not Geometry2D.intersect_polygons(body_rect, world_polygon).is_empty()
		foreground_overlap = foreground_overlap or overlaps
		var target_alpha: float = minf(float(_face_alphas[face]), 0.10) if overlaps else float(_face_alphas[face])
		face.color.a = move_toward(face.color.a, target_alpha, delta * 2.5)
	# Lift only during a cutaway, so a rim cannot run across Dasha's body.
	# Elsewhere retain the normal Y-sort relationship with furniture.
	_sprite.z_index = 3 if foreground_overlap else 0
	_player_label.z_index = 3 if foreground_overlap else 0
