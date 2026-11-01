extends SceneTree

var failures: int = 0
var sound: Node

func _initialize() -> void:
	call_deferred("run")

func check(label: String, result: bool) -> void:
	print(("PASS " if result else "FAIL ") + label)
	if not result:
		failures += 1

func validate(stream: AudioStreamWAV, label: String) -> void:
	var peak: int = 0
	for index: int in range(stream.data.size() / 2):
		peak = maxi(peak, absi(stream.data.decode_s16(index * 2)))
	check("headroom " + label, peak > 0 and peak < 30000)
	if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		check("soft edges " + label, stream.data.decode_s16(0) == 0 and abs(stream.data.decode_s16(stream.data.size() - 2)) < 5)

func preview(path: String, streams: Array, spacing: float, gain_db: float) -> void:
	var sample_rate: int = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(int((streams.size() * spacing + 1.0) * sample_rate) * 2)
	for index: int in range(streams.size()):
		var stream: AudioStreamWAV = streams[index]
		var start: int = int((0.2 + index * spacing) * sample_rate)
		for sample: int in range(stream.data.size() / 2):
			var offset: int = (start + sample) * 2
			if offset + 2 > data.size():
				break
			var value: int = data.decode_s16(offset) + int(stream.data.decode_s16(sample * 2) * db_to_linear(gain_db))
			data.encode_s16(offset, clampi(value, -32767, 32767))
	var output: AudioStreamWAV = AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.mix_rate = sample_rate
	output.data = data
	check("preview " + path, output.save_to_wav(path) == OK)

func run() -> void:
	sound = root.get_node("SoundManager")
	for property: Dictionary in sound.get_property_list():
		var value: Variant = sound.get(property.name)
		if value is AudioStreamWAV:
			validate(value, str(property.name))
	for surface: String in sound._surface_steps:
		for stream: AudioStreamWAV in sound._surface_steps[surface]:
			validate(stream, surface)
	for material_name: String in sound._material_sounds:
		validate(sound._material_sounds[material_name], material_name)
	for voice: AudioStreamPlayer in sound._sfx_voices:
		voice.stop()
	sound._last_played.clear()
	sound.play_dialogue_advance()
	sound.play_dialogue_advance()
	var active: int = 0
	for voice: AudioStreamPlayer in sound._sfx_voices:
		if voice.playing:
			active += 1
	check("duplicate dialogue request is suppressed", active == 1)
	DirAccess.make_dir_recursive_absolute("res://docs/review/audio")
	preview("res://docs/review/audio/ui-and-interactions.wav", [sound._hover_stream, sound._click_stream, sound._dialogue_advance_stream, sound._typewriter_stream, sound._paper_stream, sound._material_sounds["glass"], sound._material_sounds["wood"], sound._material_sounds["metal"], sound._phone_pickup_stream, sound._pills_stream, sound._save_stream], 0.65, -12.0)
	var footsteps: Array = []
	for surface: String in ["wood", "concrete"]:
		for index: int in range(6):
			footsteps.append(sound._surface_steps[surface][index])
	preview("res://docs/review/audio/surfaces.wav", footsteps, 82.0 / 240.0, -7.75)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var player: Node2D = current_scene.get_node("Player") as Node2D
	player.set_physics_process(false)
	player.position = Vector2(480, 290)
	check("bedroom resolves wood", player._footstep_surface() == "wood")
	player.position = Vector2(1100, 535)
	check("storage resolves concrete", player._footstep_surface() == "concrete")
	print("AUDIO_RESULT failures=", failures)
	quit(1 if failures else 0)
