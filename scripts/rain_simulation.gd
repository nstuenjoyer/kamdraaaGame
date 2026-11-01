extends RefCounted

const CELL: float = 32.0
var extent: Vector2 = Vector2(1280, 720)
var drops: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var random: RandomNumberGenerator = RandomNumberGenerator.new()
var incoming_mass: float = 0.0
var deposited_mass: float = 0.0
var runoff_mass: float = 0.0
var merge_count: int = 0
var release_count: int = 0
var _spawn_clock: float = 0.0
var _accumulator: float = 0.0

func initialize(seed_value: int = 104729, initial_count: int = 230) -> void:
	random.seed = seed_value
	drops.clear()
	trails.clear()
	incoming_mass = 0.0
	deposited_mass = 0.0
	runoff_mass = 0.0
	merge_count = 0
	release_count = 0
	_accumulator = 0.0
	_spawn_clock = 0.0
	for index: int in range(initial_count):
		var radius: float = random.randf_range(1.4, 4.5)
		if index < 12:
			radius = random.randf_range(4.8, 5.7)
		var drop: Dictionary = add_drop(Vector2(random.randf_range(0, extent.x), random.randf_range(0, extent.y)), radius)
		drop.threshold = maxf(float(drop.threshold), float(drop.mass) * 1.15)

func add_drop(position: Vector2, radius: float) -> Dictionary:
	var mass: float = pow(radius, 3.0)
	var threshold: float = pow(random.randf_range(4.8, 6.8), 3.0)
	var drop: Dictionary = {"position": position, "previous": position, "trail_anchor": position, "mass": mass, "threshold": threshold, "velocity": Vector2.ZERO, "moving": false, "alive": true, "seed": random.randf() * 100.0, "growth": random.randf_range(1.0, 5.0)}
	drops.append(drop)
	incoming_mass += mass
	return drop

func advance(delta: float) -> void:
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= 1.0 / 60.0:
		_step(1.0 / 60.0)
		_accumulator = maxf(0.0, _accumulator - 1.0 / 60.0)

func _step(delta: float) -> void:
	_spawn_clock += delta
	while _spawn_clock >= 0.1:
		_spawn_clock -= 0.1
		if drops.size() < 320:
			add_drop(Vector2(random.randf_range(0, extent.x), random.randf_range(0, extent.y)), random.randf_range(0.9, 2.7))
	for trail: Dictionary in trails:
		trail.life -= delta
	trails = trails.filter(func(trail: Dictionary) -> bool: return trail.life > 0.0)
	for drop: Dictionary in drops:
		drop.previous = drop.position
		var growth: float = float(drop.growth) * delta
		drop.mass += growth
		incoming_mass += growth
		if not drop.moving and drop.mass >= drop.threshold:
			drop.moving = true
			release_count += 1
		if drop.moving:
			var velocity: Vector2 = drop.velocity
			var drive: float = 320.0 * maxf(0.0, 1.0 - float(drop.threshold) * 0.6 / float(drop.mass))
			velocity.y = minf(330.0, maxf(0.0, velocity.y + (drive - velocity.y * 1.3) * delta))
			velocity.x = lerpf(velocity.x, sin(float(drop.position.y) * 0.035 + float(drop.seed)) * 5.0, delta * 3.0)
			drop.velocity = velocity
			drop.position += velocity * delta
			var distance: float = drop.position.distance_to(drop.previous)
			var deposit: float = minf(float(drop.mass) * 0.0012 * distance, float(drop.mass) * 0.05)
			drop.mass -= deposit
			deposited_mass += deposit
			if drop.position.distance_to(drop.trail_anchor) > 3.0:
				trails.append({"from": drop.trail_anchor, "to": drop.position, "width": pow(float(drop.mass), 1.0 / 3.0) * 0.34, "life": 12.0})
				drop.trail_anchor = drop.position
			if drop.mass < float(drop.threshold) * 0.65 and velocity.y < 3.0:
				drop.moving = false
				drop.velocity = Vector2.ZERO
		if drop.position.y > extent.y + 30.0:
			drop.alive = false
			runoff_mass += float(drop.mass)
	_merge_contacts()
	drops = drops.filter(func(drop: Dictionary) -> bool: return drop.alive)
	if trails.size() > 2200:
		trails = trails.slice(trails.size() - 2200)

func _merge_contacts() -> void:
	var grid: Dictionary = {}
	for index: int in range(drops.size()):
		if not drops[index].alive:
			continue
		var cell: Vector2i = Vector2i((drops[index].position as Vector2) / CELL)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(index)
	for index: int in range(drops.size()):
		var drop: Dictionary = drops[index]
		if not drop.alive:
			continue
		var radius: float = pow(float(drop.mass), 1.0 / 3.0)
		var start: Vector2 = drop.previous
		var end: Vector2 = drop.position
		var margin: Vector2 = Vector2.ONE * (radius + 32.0)
		var minimum: Vector2i = Vector2i((start.min(end) - margin) / CELL)
		var maximum: Vector2i = Vector2i((start.max(end) + margin) / CELL)
		for y: int in range(minimum.y, maximum.y + 1):
			for x: int in range(minimum.x, maximum.x + 1):
				for other_index: int in grid.get(Vector2i(x, y), []):
					if other_index == index:
						continue
					var other: Dictionary = drops[other_index]
					if not other.alive:
						continue
					var other_radius: float = pow(float(other.mass), 1.0 / 3.0)
					var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(other.position, start, end)
					if nearest.distance_to(other.position) > (radius + other_radius) * 0.88:
						continue
					var total: float = float(drop.mass) + float(other.mass)
					if not drop.moving:
						drop.position = (drop.position * float(drop.mass) + other.position * float(other.mass)) / total
					drop.velocity = (drop.velocity * float(drop.mass) + other.velocity * float(other.mass)) / total
					drop.moving = drop.moving or other.moving
					drop.mass = total
					other.alive = false
					radius = pow(total, 1.0 / 3.0)
					merge_count += 1
