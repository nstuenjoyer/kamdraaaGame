extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stream: AudioStreamMP3 = AudioStreamMP3.new()
	stream.data = FileAccess.get_file_as_bytes("res://docs/review/audio_sources/heartbeat_recording.mp3")
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	playback.start()
	var bytes: PackedByteArray = PackedByteArray()
	var limit: int = int(stream.get_length() * AudioServer.get_mix_rate())
	for offset: int in range(0,limit,1024):
		var samples: PackedVector2Array = playback.mix_audio(1.0,mini(1024,limit-offset))
		for sample: Vector2 in samples:
			bytes.append_array(PackedByteArray([0,0]))
			bytes.encode_s16(bytes.size()-2,int(clampf((sample.x+sample.y)*0.5,-1,1)*32767))
	var decoded: AudioStreamWAV = AudioStreamWAV.new()
	decoded.format = AudioStreamWAV.FORMAT_16_BITS
	decoded.mix_rate = int(AudioServer.get_mix_rate())
	decoded.data = bytes
	print("DECODE ",decoded.mix_rate," ",decoded.get_length()," ",decoded.save_to_wav("res://.godot/heartbeat_decoded.wav"))
	quit()
