extends RefCounted

static func move_actor(body: CharacterBody3D) -> void:
	var previous: Vector3 = body.position
	var horizontal: Vector3 = Vector3(body.velocity.x, 0, body.velocity.z)
	body.move_and_slide()
	# Match the navmesh's 25 cm climb allowance at ramp/landing corners.
	if body.is_on_floor() and body.is_on_wall() and horizontal.length() > 0.2 and body.position.distance_to(previous) < horizontal.length() * body.get_physics_process_delta_time() * 0.7:
		var raised: Transform3D = body.global_transform
		raised.origin.y += 0.26
		if not body.test_move(body.global_transform, Vector3.UP * 0.26) and not body.test_move(raised, horizontal.normalized() * 0.14):
			body.position.y += 0.26
			body.velocity = horizontal
			body.move_and_slide()
			body.apply_floor_snap()
