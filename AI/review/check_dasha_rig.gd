extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, title: String) -> void:
	print("PASS " if value else "FAIL ", title)
	if not value: failures += 1

func run() -> void:
	var model: Node3D = load("res://assets/models/characters/dasha_meshy/rig_v1/dasha_rig_v1.glb").instantiate()
	root.add_child(model)
	await process_frame
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == 1, "one imported skeleton")
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	check(skeleton.get_bone_count() == 31, "31 bones imported")
	check(skeleton.find_bone("head") >= 0 and skeleton.find_bone("bag") >= 0, "head and bag controls present")
	var skinned: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.skin != null and mesh.skin.get_bind_count() > 0: skinned = true
	check(skinned, "mesh has exported skin binding")
	var animations: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	check(animations.size() == 1, "animation player imported")
	var player: AnimationPlayer = animations[0] as AnimationPlayer
	var clip: String = ""
	for name: String in player.get_animation_list():
		if "walk_test" in name: clip = name
	check(not clip.is_empty(), "deformation test clip imported")
	var thigh: int = skeleton.find_bone("thigh.L")
	player.play(clip)
	player.advance(0)
	var rest: Quaternion = skeleton.get_bone_pose_rotation(thigh)
	player.advance(0.2)
	check(rest.angle_to(skeleton.get_bone_pose_rotation(thigh)) > 0.05, "test clip actually moves skinned skeleton")
	player.seek(0, true)
	player.stop(true)
	check(rest.angle_to(skeleton.get_bone_pose_rotation(thigh)) < 0.001, "bind pose restored")
	model.queue_free()
	await process_frame
	print("RIG_GODOT failures=", failures)
	quit(1 if failures else 0)
