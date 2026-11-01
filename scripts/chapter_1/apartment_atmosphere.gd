extends Node2D

var host: Node2D
var hum: AudioStreamPlayer2D
var elapsed: float = 0.0
var last_room: String = "bedroom"
var drip: AudioStreamPlayer2D
var drip_timer: float = 2.0
var record: AudioStreamPlayer2D

func setup(controller: Node2D) -> void:
	host = controller
	name = "Atmosphere"
	drip = AudioStreamPlayer2D.new()
	drip.bus = "SFX"
	drip.position = ApartmentWorld.iso(Vector2(1140, 180))
	drip.volume_db = -32
	drip.max_distance = 650
	drip.stream = drip_stream()
	add_child(drip)
	record = AudioStreamPlayer2D.new()
	record.bus = "SFX"
	record.position = ApartmentWorld.iso(Vector2(515, 1280))
	record.volume_db = -80
	record.max_distance = 950
	record.stream = record_stream()
	add_child(record)
	record.play()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){ vec2 p=UV*2.0-1.0; float v=smoothstep(0.38,1.42,length(p)); float n=fract(sin(dot(FRAGCOORD.xy+TIME*3.0,vec2(12.9898,78.233)))*43758.5453); COLOR=vec4(vec3(0.015,0.025,0.032), v*0.20+n*0.018); }"
	var vignette_material: ShaderMaterial = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette.material = vignette_material
	layer.add_child(vignette)

static func make_stream(electric: bool) -> AudioStreamWAV:
	var rate: int = 22050
	var length: int = rate * 6
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(length * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 63109 if electric else 714021
	var low: float = 0.0
	var slower: float = 0.0
	for i: int in length:
		var time: float = float(i) / rate
		var noise: float = rng.randf_range(-1, 1)
		low = lerpf(low, noise, 0.075)
		slower = lerpf(slower, noise, 0.003)
		var wave: float = low * 0.8 + slower * 1.4
		if electric: wave = sin(TAU * 50 * time) * 0.19 + sin(TAU * 100 * time) * 0.055 + low * 0.08
		var edge: float = minf(1.0, minf(float(i), float(length - 1 - i)) / (rate * 0.08))
		bytes.encode_s16(i * 2, int(clampf(wave * edge, -0.7, 0.7) * 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = length
	return stream

static func drip_stream() -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(7938)
	for i: int in 3969:
		var t: float = float(i) / 22050.0
		var envelope: float = minf(1.0, t / 0.009) * exp(-t * 34.0)
		var sample: float = (sin(TAU * 520 * t) * 0.19 + sin(TAU * 870 * t) * 0.06) * envelope
		data.encode_s16(i * 2, int(sample * 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream

static func record_stream() -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(22050 * 8 * 2)
	var notes: Array[float] = [146.83, 174.61, 164.81, 130.81, 146.83, 110.0, 130.81, 164.81]
	for i: int in 22050 * 8:
		var t: float = float(i) / 22050.0
		var beat: float = fmod(t, 1.0)
		var envelope: float = minf(1, beat / 0.055) * (1.0 - beat) * exp(-beat * 1.8)
		var phase: float = TAU * notes[int(t)] * t
		var value: float = (sin(phase) * 0.14 + sin(phase * 2) * 0.025) * envelope
		data.encode_s16(i * 2, int(value * 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050 * 8
	return stream

func _process(delta: float) -> void:
	if host == null or host.ui == null: return
	elapsed += delta
	drip_timer -= delta
	if drip_timer <= 0 and not host.state.has("tap_closed"):
		drip.play()
		drip_timer = 2.3
	record.volume_db = move_toward(record.volume_db, -30.0 if host.state.has("record_playing") and host.state.has("power") else -80.0, delta * 18)
	var room: String = host.world.room_at(host.player.position)
	if room != last_room and not host.is_blocked():
		last_room = room
		if room == "study" and host.state.mark("entered_study"):
			SoundManager.play_material_interact("paper")
			host.ui.notify("Пыль на столе стёрта совсем недавно. На ручке картотеки ещё блестит влажный след.")
		elif room == "utility" and host.state.mark("entered_utility"):
			host.ui.notify("В тесной постирочной слышны трубы. Здесь хранятся инструменты и журнал электрика.")
		elif room == "back_hall" and host.state.mark("entered_back_hall"):
			SoundManager.play_material_interact("wood")
			host.ui.notify("За стеной скрипнула половица. Даша замерла — звук не повторился.")
	queue_redraw()

func _draw() -> void:
	if host == null: return
	var center: Vector2 = ApartmentWorld.iso(Vector2(300, 230))
	for i: int in 26:
		var cycle: float = fmod(elapsed * (0.7 + (i % 4) * 0.1) + i * 1.73, 25.0) / 25.0
		var point: Vector2 = center + Vector2(sin(i * 2.9) * 150 + cycle * 24, cos(i * 1.4) * 70 + cycle * 20)
		draw_circle(point, 0.65 + (i % 2) * 0.35, Color(0.76, 0.78, 0.67, sin(cycle * PI) * 0.14))
