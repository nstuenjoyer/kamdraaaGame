extends Node2D

const Simulation = preload("res://scripts/rain_simulation.gd")
var simulation: RefCounted = Simulation.new()
var _drops: MultiMeshInstance2D
var _trails: MultiMeshInstance2D

func _ready() -> void:
	simulation.random.randomize()
	simulation.initialize(simulation.random.randi())
	_trails = _make_layer(2200, preload("res://shaders/glass_trail.gdshader"))
	_drops = _make_layer(320, preload("res://shaders/glass_drop.gdshader"))

func _make_layer(capacity: int, shader: Shader) -> MultiMeshInstance2D:
	var layer: MultiMeshInstance2D = MultiMeshInstance2D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(2, 2)
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = capacity
	instances.visible_instance_count = 0
	layer.multimesh = instances
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	layer.material = material
	add_child(layer)
	return layer

func restrict_to_window() -> void:
	for layer: MultiMeshInstance2D in [_drops, _trails]:
		(layer.material as ShaderMaterial).set_shader_parameter("window_mask_enabled", true)

func _process(delta: float) -> void:
	var canvas: Vector2 = (get_parent() as Control).size
	if canvas.y <= 0.0:
		return
	var scale_factor: float = canvas.y / 720.0
	var width: float = canvas.x / scale_factor
	if not is_equal_approx(width, simulation.extent.x):
		var ratio: float = width / simulation.extent.x
		for drop: Dictionary in simulation.drops:
			drop.position.x *= ratio
			drop.previous.x *= ratio
			drop.trail_anchor.x *= ratio
		for trail: Dictionary in simulation.trails:
			trail.from.x *= ratio
			trail.to.x *= ratio
		simulation.extent.x = width
	simulation.advance(delta)
	_drops.multimesh.visible_instance_count = simulation.drops.size()
	for index: int in range(simulation.drops.size()):
		var drop: Dictionary = simulation.drops[index]
		var radius: float = pow(float(drop.mass), 1.0 / 3.0)
		var speed: float = float(drop.velocity.y)
		var elongation: float = 1.0 + minf(speed / 350.0, 0.65)
		var size: Vector2 = Vector2(radius / sqrt(elongation), radius * elongation) * scale_factor
		_drops.multimesh.set_instance_transform_2d(index, Transform2D(0.0, size, 0.0, drop.position * scale_factor))
		_drops.multimesh.set_instance_custom_data(index, Color(radius * scale_factor, minf(speed / 220.0, 1.0), float(drop.seed) / 100.0, 1.0))
	_trails.multimesh.visible_instance_count = simulation.trails.size()
	for index: int in range(simulation.trails.size()):
		var trail: Dictionary = simulation.trails[index]
		var difference: Vector2 = trail.to - trail.from
		var center: Vector2 = (trail.from + trail.to) * 0.5 * scale_factor
		var size: Vector2 = Vector2(float(trail.width), difference.length() * 0.5 + 1.0) * scale_factor
		_trails.multimesh.set_instance_transform_2d(index, Transform2D(difference.angle() - PI * 0.5, size, 0.0, center))
		_trails.multimesh.set_instance_custom_data(index, Color(float(trail.life) / 12.0, 0, 0, 1))
