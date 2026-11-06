extends RefCounted

var meshes: Array[MeshInstance3D] = []
var hold: Dictionary = {}

func collect(node: Node) -> void:
	if node is MeshInstance3D and not node.get_meta("permanent_shadow", false): meshes.append(node)
	for child: Node in node.get_children(): collect(child)

func blocks(mesh: MeshInstance3D, camera: Camera3D, player: Vector3) -> bool:
	var inverse: Transform3D = mesh.global_transform.affine_inverse()
	var origin: Vector3 = inverse * camera.global_position
	var bounds: AABB = mesh.get_aabb()
	for height: float in [0.5, 1.05, 1.65]:
		for side: float in [-0.18, 0.0, 0.18]:
			var target: Vector3 = player + Vector3.UP * height + camera.global_basis.x * side
			# Stop before the actor itself, not beyond it.
			target += target.direction_to(camera.global_position) * 0.12
			if bounds.intersects_segment(origin, inverse * target) != null: return true
	return false

func update(camera: Camera3D, player: Vector3, delta: float) -> void:
	var blocked_meshes: Dictionary = {}
	var blocked_planes: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		if is_instance_valid(mesh) and mesh.is_visible_in_tree() and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			blocked_meshes[mesh.get_instance_id()] = blocks(mesh, camera, player)
			if mesh.has_meta("wall_plane") and blocked_meshes[mesh.get_instance_id()]: blocked_planes[mesh.get_meta("wall_plane")] = true
	for mesh: MeshInstance3D in meshes:
		if not is_instance_valid(mesh): continue
		var eligible: bool = mesh.is_visible_in_tree() and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var support: MeshInstance3D = (mesh.get_meta("support_mesh") as MeshInstance3D) if mesh.has_meta("support_mesh") else null
		var same_wall: bool = mesh.has_meta("wall_plane") and blocked_planes.has(mesh.get_meta("wall_plane"))
		var mounted: bool = is_instance_valid(support) and (bool(blocked_meshes.get(support.get_instance_id(), false)) or (support.has_meta("wall_plane") and blocked_planes.has(support.get_meta("wall_plane"))))
		var blocked: bool = eligible and (bool(blocked_meshes.get(mesh.get_instance_id(), false)) or same_wall or mounted)
		var remaining: float = 0.12 if blocked else maxf(0, float(hold.get(mesh.get_instance_id(), 0)) - delta)
		hold[mesh.get_instance_id()] = remaining
		var target: float = 0.72 if eligible and remaining > 0 else 0.0
		mesh.transparency = move_toward(mesh.transparency, target, delta * 4.5)

		if mesh.get_parent().has_meta("wall_anchor"):
			for child: Node in mesh.get_parent().get_children():
				if child is GPUParticles3D: child.transparency = mesh.transparency
