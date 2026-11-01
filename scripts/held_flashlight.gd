class_name HeldFlashlight
extends Node2D

const SOCKETS: GDScript = preload("res://scripts/dasha_hand_sockets.gd")
const ARM_MASK: Shader = preload("res://shaders/held_arm_mask.gdshader")
const POCKET_MASK: Shader = preload("res://shaders/flashlight_pocket.gdshader")
const DRAW_SECONDS: float = 0.76
const STOW_SECONDS: float = 0.56
var actor: CharacterBody2D
var animator: DashaAnimation
var equip_amount: float = 0.0
var lens_position: Vector2 = Vector2(0,-58)
var emission_height: float = 58.0
var arm_mask: ShaderMaterial
var upper: Sprite2D
var forearm: Sprite2D
var palm: Sprite2D
var torch: Sprite2D
var textures: Dictionary = {}
var wrist_position: Vector2
var shoulder_position: Vector2
var elbow_position: Vector2
var lamp_angle: float = PI*0.5
var pocket_material: ShaderMaterial

func setup(body: CharacterBody2D, animation: DashaAnimation) -> void:
	name = "HeldFlashlight"
	actor = body
	animator = animation
	set_process(false)
	arm_mask = ShaderMaterial.new()
	arm_mask.shader = ARM_MASK
	for facing: String in ["front","back"]:
		for part: String in ["upper_arm","forearm","hand","flashlight"]:
			textures[facing+part] = load("res://assets/sprites/dasha_flashlight/"+facing+"_"+part+".png")
	upper = _part()
	forearm = _part()
	upper.self_modulate = Color(0.76,0.86,0.73,1)
	forearm.self_modulate = upper.self_modulate
	torch = _part()
	pocket_material = ShaderMaterial.new()
	pocket_material.shader = POCKET_MASK
	torch.material = pocket_material
	palm = _part()
	visible = false

func _part() -> Sprite2D:
	var part: Sprite2D = Sprite2D.new()
	part.centered = false
	part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	part.light_mask = animator.sprite.light_mask
	add_child(part)
	return part

func snap(enabled: bool) -> void:
	equip_amount = 1.0 if enabled else 0.0

func update_pose(delta: float, aim: float, requested: bool) -> void:
	var step: float = 0.0 if actor.is_control_locked else delta / (DRAW_SECONDS if requested else STOW_SECONDS)
	equip_amount = move_toward(equip_amount,1.0 if requested else 0.0,step)
	visible = equip_amount > 0.005
	var sprite: Sprite2D = animator.sprite
	if not visible:
		if sprite.material == arm_mask: sprite.material = null
		torch.visible = false
		return
	var table: String = "idle" if sprite.texture == DashaAnimation.IDLE_ATLAS else "main"
	var socket: Dictionary = SOCKETS.POSES[table][sprite.frame]
	var scale_value: float = animator.base_scale.x
	var shoulder_px: Vector2 = Vector2(socket.shoulder[0],socket.shoulder[1])
	var target_shoulder: Vector2 = _local_point(shoulder_px)
	var old_hand: Vector2 = Vector2(socket.hand[0],socket.hand[1])
	var rest_px: Array = socket.hand if socket.erase else socket.rest
	var rest_offset: Vector2 = _local_point(Vector2(rest_px[0],rest_px[1]))-target_shoulder
	var back: bool = animator.facing == "back"
	var side: float = (1.0 if back else -1.0)*(-1.0 if sprite.flip_h else 1.0)
	# The body has discrete front/back and reflected sprites. Keep the shoulder
	# on that same sprite, including its turn frame, rather than leaving a limb
	# floating at the previous shoulder while the body has already turned.
	shoulder_position = target_shoulder
	var shoulder: Vector2 = shoulder_position
	rest_offset.x = side*absf(rest_offset.x)
	emission_height = lerpf(58.0,34.0,animator.crouch_amount)
	var direction: Vector2 = Vector2.RIGHT.rotated(aim)
	# Aiming pivots the wrist. It never swings the whole arm above the shoulder.
	var held: Vector2 = shoulder+Vector2(side*12.0+direction.x*10.0,18.0+direction.y*3.0)*scale_value
	var pocket: Vector2 = shoulder+Vector2(side*4.0,36.0)*scale_value
	var reach_pocket: float = smoothstep(0.0,0.28,equip_amount)
	var lift: float = smoothstep(0.42,0.96,equip_amount)
	var wrist: Vector2 = (shoulder+rest_offset).lerp(pocket,reach_pocket)
	if lift > 0.0:
		var arc: Vector2 = shoulder+Vector2(side*27.0,31.0)*scale_value
		wrist = pocket.lerp(arc,lift).lerp(arc.lerp(held,lift),lift)
	lamp_angle = lerp_angle(PI*0.5,aim,smoothstep(0.38,0.86,equip_amount))
	var muzzle_offset: Vector2 = Vector2.RIGHT.rotated(lamp_angle)*19.0*scale_value*0.8
	var wanted_lens: Vector2 = wrist + muzzle_offset
	var world: Node = actor.get_parent()
	if world.has_method("clear_line"):
		var ground: Vector2 = wanted_lens+Vector2(0,emission_height)
		if not world.clear_line(actor.global_position,actor.global_position+ground):
			var low: float = 0.0
			var high: float = 1.0
			for index: int in 8:
				var middle: float = (low+high)*0.5
				if world.clear_line(actor.global_position,actor.global_position+ground*middle): low = middle
				else: high = middle
			wanted_lens = ground*maxf(0,low-0.03)-Vector2(0,emission_height)
			wrist = wanted_lens-muzzle_offset
	var upper_length: float = 22.0*scale_value
	var lower_length: float = 23.0*scale_value
	var reach: Vector2 = wrist-shoulder
	var distance: float = clampf(reach.length(),absf(upper_length-lower_length)+0.1,upper_length+lower_length-0.03*scale_value)
	wrist = shoulder+reach.normalized()*distance
	var bend: float = acos(clampf((upper_length*upper_length+distance*distance-lower_length*lower_length)/(2.0*upper_length*distance),-1,1))
	# Bend towards the anatomical outside of this body view. Neither a vertical
	# aim nor tucking the hand against a wall may switch the IK solution.
	var elbow: Vector2 = shoulder+Vector2.RIGHT.rotated(reach.angle()+side*bend)*upper_length
	elbow_position = elbow
	var prefix: String = "back" if back else "front"
	upper.texture = textures[prefix+"upper_arm"]
	forearm.texture = textures[prefix+"forearm"]
	palm.texture = textures[prefix+"hand"]
	torch.texture = textures[prefix+"flashlight"]
	_bone(upper,Vector2(34,6),Vector2(6,26),shoulder,elbow)
	_bone(forearm,Vector2(31,5 if back else 6),Vector2(5,13 if back else 14),elbow,wrist)
	palm.offset = -Vector2(6,7)
	palm.scale = Vector2.ONE*scale_value*0.7
	palm.position = wrist
	palm.rotation = lamp_angle-PI
	torch.offset = -Vector2(20,6)
	torch.scale = Vector2.ONE*scale_value*0.8
	torch.position = wrist
	torch.rotation = lamp_angle-PI
	torch.visible = equip_amount >= 0.34
	pocket_material.set_shader_parameter("pocket_y",actor.global_position.y+pocket.y+3.0*scale_value)
	pocket_material.set_shader_parameter("clipping",equip_amount < 0.66)
	# This is the far arm in both body views: the coat must occlude its
	# shoulder and elbow. Only the exposed sleeve outside the silhouette shows.
	upper.z_index = -1
	forearm.z_index = -1
	palm.z_index = -1 if back else 0
	torch.z_index = -1 if back else 0
	wrist_position = wrist
	lens_position = wrist+muzzle_offset
	# The existing arm is replaced at the same position, not dissolved into a
	# second translucent limb. Only the lamp is concealed by the coat pocket.
	modulate.a = 1.0
	arm_mask.set_shader_parameter("shoulder",shoulder_px)
	arm_mask.set_shader_parameter("old_hand",old_hand)
	arm_mask.set_shader_parameter("body_x",socket.body_x)
	arm_mask.set_shader_parameter("strength",1.0 if socket.erase else 0.0)
	sprite.material = arm_mask

func _local_point(point: Vector2) -> Vector2:
	var sprite: Sprite2D = animator.sprite
	if sprite.flip_h: point.x = 160.0-point.x
	return (point+sprite.offset)*sprite.scale+sprite.position

func _bone(part: Sprite2D, proximal: Vector2, distal: Vector2, a: Vector2, b: Vector2) -> void:
	var native: Vector2 = distal-proximal
	part.offset = -proximal
	part.scale = Vector2.ONE*a.distance_to(b)/native.length()
	part.position = a
	part.rotation = (b-a).angle()-native.angle()
