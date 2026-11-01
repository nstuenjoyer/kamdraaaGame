extends SceneTree

const Simulation = preload("res://scripts/rain_simulation.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func run() -> void:
	var isolated: RefCounted = Simulation.new()
	isolated.initialize(17, 0)
	var small: Dictionary = isolated.add_drop(Vector2(200, 100), 2.0)
	isolated.advance(0.2)
	check("small drop stays pinned while accumulating", small.position == Vector2(200, 100) and small.mass > 8.0)
	var moving: Dictionary = isolated.add_drop(Vector2(400, 100), 7.0)
	var collected: Dictionary = isolated.add_drop(Vector2(400, 130), 2.0)
	var beside: Dictionary = isolated.add_drop(Vector2(430, 130), 2.0)
	for frame: int in range(90):
		isolated.advance(1.0 / 60.0)
	check("heavy drop releases and accelerates", moving.position.y > 130.0 and moving.velocity.y > 0.0)
	check("moving drop gathers water on its path", not collected.alive)
	check("moving drop does not vacuum neighboring lane", beside.alive)
	check("moving drop leaves a persistent wet trace", not isolated.trails.is_empty())
	var totals: Array[float] = []
	for fps: int in [30, 60, 144]:
		var simulation: RefCounted = Simulation.new()
		simulation.initialize(104729, 230)
		for frame: int in range(fps * 20):
			simulation.advance(1.0 / float(fps))
		var mass: float = 0.0
		var pinned: int = 0
		for drop: Dictionary in simulation.drops:
			mass += float(drop.mass)
			if not drop.moving:
				pinned += 1
		check("mass conserved including deposits and runoff", absf(mass + simulation.deposited_mass + simulation.runoff_mass - simulation.incoming_mass) < 0.1)
		check("some droplets stay pinned", pinned > 20)
		check("natural merging and releases occur", simulation.merge_count > 0 and simulation.release_count > 2)
		check("simulation stays bounded", simulation.drops.size() <= 320 and simulation.trails.size() <= 2200)
		totals.append(mass)
		print("RAIN_STATS fps=", fps, " drops=", simulation.drops.size(), " merges=", simulation.merge_count, " releases=", simulation.release_count)
	check("motion is independent of display frame rate", absf(totals.max() - totals.min()) < 10.0)
	print("RAIN_RESULT failures=", failures)
	quit(1 if failures else 0)
