extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound: Node = root.get_node("SoundManager")
	var variants: Array = sound._footstep_variants
	var preview: AudioStreamWAV = AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.mix_rate = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(22050 * 5 * 2)
	var valid: bool = variants.size() == 6
	for stream: AudioStreamWAV in variants:
		var peak: int = 0
		for index: int in range(stream.data.size() / 2):
			peak = maxi(peak, absi(stream.data.decode_s16(index * 2)))
		valid = valid and peak > 100 and peak < 32767
		valid = valid and stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0
	for step: int in range(12):
		var stream: AudioStreamWAV = variants[step % 6]
		var start: int = int((0.3 + step * 82.0 / 240.0) * 22050.0)
		for index: int in range(stream.data.size() / 2):
			data.encode_s16((start + index) * 2, int(stream.data.decode_s16(index * 2) * db_to_linear(-7.75)))
	preview.data = data
	DirAccess.make_dir_recursive_absolute("res://docs/review/audio")
	valid = valid and preview.save_to_wav("res://docs/review/audio/footsteps.wav") == OK
	print("FOOTSTEPS_RESULT variants=", variants.size(), " valid=", valid)
	quit(0 if valid else 1)
