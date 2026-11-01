extends SceneTree

var failures: int = 0
var manager: Node
var anxiety: Node
var flashlight: Node

func _initialize() -> void:
	call_deferred("run")

func check(label: String, value: bool) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func simulate(seconds: float, fps: int) -> void:
	for index: int in range(roundi(seconds * fps)):
		anxiety._process(1.0 / fps)
		manager._process(1.0 / fps)

func run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	manager = root.get_node("ParanoiaManager")
	anxiety = current_scene.get_node("DarknessAnxiety")
	flashlight = current_scene.get_node("Player/Flashlight")
	manager.set_process(false)
	anxiety.set_process(false)
	var levels: Array[float] = []
	for fps: int in [30, 60, 144]:
		manager.reset_to_default()
		anxiety._darkness_duration = 0.0
		anxiety._is_player_in_dark_zone = true
		flashlight.toggle_flashlight(false)
		simulate(3.0, fps)
		check("brief darkness does not cause panic", not manager.is_panic() and manager.get_paranoia() < 40.0)
		simulate(6.0, fps)
		levels.append(manager.get_paranoia())
		check("panic after sustained 9 seconds at %d FPS" % fps, manager.is_panic())
		var peak: float = manager.get_paranoia()
		flashlight.toggle_flashlight(true)
		simulate(4.0, fps)
		check("light stops growth without instant recovery", absf(manager.get_paranoia() - peak) < 1.0)
		simulate(16.0, fps)
		check("recovery is gradual", manager.get_paranoia() > peak - 12.0 and manager.get_paranoia() < peak - 5.0)
	check("growth independent of frame rate", absf(levels.max() - levels.min()) < 1.0)
	manager.set_paranoia(85.0)
	for index: int in range(20):
		flashlight.toggle_flashlight(index % 2 == 0)
		simulate(0.1, 60)
	check("flashlight spam cannot reduce panic", manager.get_paranoia() >= 85.0)
	paused = true
	var before_pause: float = manager.get_paranoia()
	manager._process(30.0)
	check("pause freezes stress", manager.get_paranoia() == before_pause)
	paused = false
	manager.reduce_paranoia(40.0)
	check("pills still provide deliberate relief", manager.get_paranoia() <= before_pause - 39.0)
	print("PANIC_RESULT failures=", failures)
	quit(1 if failures else 0)
