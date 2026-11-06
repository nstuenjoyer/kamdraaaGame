class_name DashaAnimation3D
extends RefCounted

# In-place loops: the physics body alone owns world movement. Distances match
# the authored cycles; contact markers are at phase 0 and 0.5 for both feet.
const CYCLE_DISTANCE: Dictionary = {
	"walk": 2.0 * 0.34 / 0.60, "run": 2.2, "sneak": 2.0 * 0.20 / 0.72,
	"stairs_up": 2.0 * 0.22 / 0.64, "stairs_down": 2.0 * 0.22 / 0.64
}
const BLEND_TIME: float = 0.20
const START_BLEND_TIME: float = 0.24
const STOP_BLEND_TIME: float = 0.24
const SLOPE_HOLD_TIME: float = 0.12
const START_PHASE: float = 0.25
const MIN_MOVING_SPEED: float = 0.06
var player: AnimationPlayer
var clips: Dictionary = {}
var state: String = ""
var phase: float = START_PHASE
var playback_rate: float = 1.0
var slope_state: String = ""
var slope_candidate: String = ""
var slope_elapsed: float = 0.0

func setup(model: Node3D) -> void:
	var nodes: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if nodes.is_empty(): return
	player = nodes[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: String in player.get_animation_list():
		var label: String = key.get_slice("/", key.get_slice_count("/") - 1)
		if label == "idle" or CYCLE_DISTANCE.has(label):
			clips[label] = key
			player.get_animation(key).loop_mode = Animation.LOOP_LINEAR
	update(0.0, Vector3.ZERO, true, "walk", false)

func update(delta: float, displacement: Vector3, grounded: bool, mode: String, on_slope: bool, locked: bool = false) -> int:
	if player == null: return 0
	var distance: float = Vector2(displacement.x, displacement.z).length()
	# Loading/teleporting must not turn into a burst of animation or footsteps.
	var moving: bool = not locked and grounded and delta > 0.0 and distance > delta * MIN_MOVING_SPEED and distance < 0.5
	var next: String = mode if moving else "idle"
	if moving:
		var slope: String = ""
		if on_slope and absf(displacement.y) > delta * 0.08:
			slope = "stairs_up" if displacement.y > 0.0 else "stairs_down"
		if slope != slope_candidate:
			slope_candidate = slope
			slope_elapsed = 0.0
		slope_elapsed += delta
		if slope_elapsed >= SLOPE_HOLD_TIME: slope_state = slope_candidate
		if not slope_state.is_empty(): next = slope_state
	else:
		slope_state = ""
		slope_candidate = ""
		slope_elapsed = 0.0
	if not clips.has(next): return 0
	if next != state:
		var was_idle: bool = state == "idle" or state.is_empty()
		var blend: float = STOP_BLEND_TIME if next == "idle" else (START_BLEND_TIME if was_idle else BLEND_TIME)
		# Restart from a passing pose, so an idle foot is lifted gradually rather
		# than snapping directly to the maximum stride/contact pose. Mode switches
		# retain the existing left/right phase.
		if was_idle and next != "idle": phase = START_PHASE
		state = next
		player.play(clips[state], blend)
		if state != "idle": player.seek(phase * player.current_animation_length, true)
	var contacts: int = 0
	playback_rate = 1.0
	if moving:
		var progress: float = distance / float(CYCLE_DISTANCE[state])
		contacts = floori((phase + progress) * 2.0) - floori(phase * 2.0)
		phase = fposmod(phase + progress, 1.0)
		playback_rate = progress * player.current_animation_length / delta
	player.advance(delta * playback_rate)
	return contacts
