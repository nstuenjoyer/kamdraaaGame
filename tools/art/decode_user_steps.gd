extends SceneTree

func _initialize() -> void:
	var stream: AudioStreamMP3 = AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("res://assets/audio/footsteps_user/source/steps-2.mp3")
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var bytes: PackedByteArray = PackedByteArray()
	var rate: int = int(AudioServer.get_mix_rate())
	var count: int = int(stream.get_length() * rate)
	for offset: int in range(0, count, 1024):
		for sample: Vector2 in playback.mix_audio(1.0, mini(1024, count - offset)):
			bytes.resize(bytes.size() + 2)
			bytes.encode_s16(bytes.size() - 2, int(clampf((sample.x + sample.y) * 0.5, -1, 1) * 32767))
	var decoded: AudioStreamWAV = AudioStreamWAV.new()
	decoded.format = AudioStreamWAV.FORMAT_16_BITS
	decoded.mix_rate = rate
	decoded.data = bytes
	var error: Error = decoded.save_to_wav("res://.godot/user_steps_decoded.wav")
	print("USER_STEPS_DECODE rate=", rate, " duration=", decoded.get_length(), " error=", error)
	quit(0 if error == OK else 1)
