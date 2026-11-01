class_name DashaAnimation
extends RefCounted

# Registered, separately drawn poses. No UV distortion, whole-body squash or rotation.
const ATLAS: Texture2D = preload("res://assets/sprites/dasha_animation/dasha_atlas.png")
const IDLE_ATLAS: Texture2D = preload("res://assets/sprites/dasha_animation/dasha_idle_atlas.png")
const FRAME_COUNT: int = 8
const TRANSITION_SECONDS: float = 0.30
const STRIDES: Dictionary = {"walk": 164.0, "run": 220.0, "sneak": 100.0}
var sprite: Sprite2D
var animation_state: String = "idle"
var facing: String = "front"
var frame_index: int = 0
var crouch_amount: float = 0.0
var cycle_phase: float = 0.0
var last_walk_distance: float = 0.0
var idle_phase: float = 0.0
var base_scale: Vector2 = Vector2.ONE

func setup(target: Sprite2D) -> void:
	sprite = target
	# Existing scenes set size using the original 456px-tall sprite.
	var character_height: float = 456.0 * target.scale.y
	sprite.texture = ATLAS
	sprite.material = null
	sprite.hframes = 8
	sprite.vframes = 8
	sprite.centered = false
	sprite.offset = Vector2(-80, -244)
	sprite.scale = Vector2.ONE * character_height / 200.0
	base_scale = sprite.scale
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_pose("idle", 0, "front")

func update(delta: float, velocity: Vector2, mode: String, walk_distance: float, locked: bool, desired_direction: Vector2 = Vector2.ZERO) -> void:
	var moving: bool = not locked and velocity.length() > 20.0
	var distance: float = maxf(0.0, walk_distance - last_walk_distance)
	last_walk_distance = walk_distance
	var look: Vector2 = desired_direction if not desired_direction.is_zero_approx() else velocity
	if not locked and (moving or not desired_direction.is_zero_approx()):
		if look.y < -absf(look.x) * 0.35:
			facing = "back"
		else:
			facing = "front"
		if absf(look.x) > 0.01: sprite.flip_h = look.x > 0
	var wants_crouch: bool = mode == "sneak" and not locked
	var previous_amount: float = crouch_amount
	crouch_amount = move_toward(crouch_amount, 1.0 if wants_crouch else 0.0, delta / TRANSITION_SECONDS)
	if crouch_amount > 0.0 and crouch_amount < 1.0:
		show_pose("crouch_enter" if crouch_amount >= previous_amount else "crouch_exit", roundi(crouch_amount * 7.0), facing)
		return
	if moving:
		var stride: float = STRIDES.get(mode, STRIDES.walk)
		cycle_phase = fmod(cycle_phase + distance / stride, 1.0)
		show_pose("crouch_walk" if wants_crouch else "run" if mode == "run" else "walk", mini(7, int(cycle_phase * 8.0)), facing)
	else:
		cycle_phase = 0.0
		if not locked: idle_phase = fmod(idle_phase + maxf(delta, 0.0) / 3.2, 1.0)
		show_pose("crouch_idle" if wants_crouch else "idle", mini(7,int(idle_phase*8.0)), facing)

func show_pose(state: String, index: int, direction: String) -> void:
	animation_state = state
	facing = direction
	frame_index = clampi(index, 0, 7)
	# Only a tiny resting chest movement, never a per-state character resize.
	sprite.scale = base_scale
	if state == "crouch_idle" or (state == "idle" and facing == "back"):
		sprite.scale.y *= 1.0 - pow(sin(idle_phase*TAU),2.0)*0.006
	if state in ["idle", "crouch_idle"]:
		sprite.texture = IDLE_ATLAS
		sprite.vframes = 4
		var idle_row: int = (2 if state == "crouch_idle" else 0) + (1 if facing == "back" else 0)
		sprite.frame = idle_row * FRAME_COUNT + frame_index
		return
	sprite.texture = ATLAS
	sprite.vframes = 8
	var row: int = {"walk": 0, "run": 1, "crouch_walk": 2}.get(state, 3)
	if facing == "back": row += 4
	sprite.frame = row * FRAME_COUNT + frame_index

func step_distance(mode: String) -> float:
	return float(STRIDES.get(mode, STRIDES.walk)) * 0.5

func settle(mode: String) -> void:
	# Modal UI disables physics immediately after locking the player. Resolve the
	# still pose synchronously, without finishing a half-completed crouch by force.
	if crouch_amount > 0.0 and crouch_amount < 1.0:
		show_pose("crouch_enter" if mode == "sneak" else "crouch_exit",roundi(crouch_amount*7.0),facing)
		return
	var crouched: bool = crouch_amount >= 1.0
	crouch_amount = 1.0 if crouched else 0.0
	cycle_phase = 0.0
	show_pose("crouch_idle" if crouched else "idle", mini(7,int(idle_phase*8.0)), facing)
