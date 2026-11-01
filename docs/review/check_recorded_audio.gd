extends SceneTree

var checks: int = 0
var failures: int = 0
var beats: int = 0
var sound: Node
var manager: Node

func _initialize() -> void: call_deferred("run")

func check(title: String, value: bool) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + title)
	if not value: failures += 1

func silent_heart() -> bool:
	return not sound._heart_s1_player.playing and not sound._heart_s2_player.playing and sound._pending_dub < 0

func validate_pcm(stream: AudioStreamWAV, label: String) -> void:
	check(label + " uncompressed recording", stream.format == AudioStreamWAV.FORMAT_16_BITS)
	var peak: int = 0
	for index: int in stream.data.size() / 2: peak = maxi(peak,absi(stream.data.decode_s16(index*2)))
	check(label + " nonzero signal and headroom", peak > 1000 and peak < 23000)
	check(label + " soft sample boundaries", stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size()-2) == 0)

func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("/.godot/chapter-check-"):
		push_error("Use tools/run_recorded_audio_checks.ps1")
		quit(1)
		return
	sound = root.get_node("SoundManager")
	manager = root.get_node("ParanoiaManager")
	manager.heartbeat_pulsed.connect(func(_bpm: int, _intensity: float) -> void: beats += 1)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	check("menu heartbeat manager inactive", not manager.is_active)
	check("menu emits no heartbeat pulses", beats == 0)
	check("menu has no beat tails or scheduled dub", silent_heart())
	check("recorded menu rain starts", sound._rain_player.playing)
	check("old bass drone not playing in menu", not sound._music_player.playing)
	var rain: AudioStreamWAV = sound._rain_player.stream
	check("rain loop full recording length", rain.loop_mode == AudioStreamWAV.LOOP_FORWARD and rain.get_length() > 10.0 and rain.stereo)
	check("rain loop stereo endpoints match", abs(rain.data.decode_s16(0)-rain.data.decode_s16(rain.data.size()-4)) < 5 and abs(rain.data.decode_s16(2)-rain.data.decode_s16(rain.data.size()-2)) < 5)
	validate_pcm(sound._paranoia_stream,"S1")
	validate_pcm(sound._heart_s2_stream,"S2")
	# Audio lifecycle fixture avoids constructing the changing apartment art.
	# It uses the real historical-game scene path recognized by the manager.
	current_scene.queue_free()
	await process_frame
	var game: Node2D = Node2D.new()
	game.scene_file_path = "res://scenes/main.tscn"
	root.add_child(game)
	current_scene = game
	scene_changed.emit()
	await create_timer(0.4).timeout
	check("rain fades out on game transition", not sound._rain_player.playing)
	check("game scene activates manager", manager.is_active)
	manager.set_process(false)
	sound.stop_heartbeat()
	manager._heartbeat_timer = 0.0
	manager.set_paranoia(100)
	manager._process(0.01)
	check("game stress triggers S1", sound._heart_s1_player.playing and beats > 0)
	check("S1 original pitch preserved", is_equal_approx(sound._heart_s1_player.pitch_scale,1.0))
	await create_timer(0.12).timeout
	check("second sound follows S1", sound._heart_s2_player.playing)
	check("S2 original pitch preserved", is_equal_approx(sound._heart_s2_player.pitch_scale,1.0))
	sound.stop_heartbeat()
	sound.play_heartbeat_pulse(68,0.3)
	var calm_spacing: float = sound._pending_dub
	sound.stop_heartbeat()
	sound.play_heartbeat_pulse(172,1.0)
	var panic_spacing: float = sound._pending_dub
	check("BPM changes spacing without changing pitch", calm_spacing > panic_spacing and panic_spacing >= 0.09)
	check("dedicated heartbeat voices outside Foley pool", not sound._sfx_voices.has(sound._heart_s1_player) and not sound._sfx_voices.has(sound._heart_s2_player))
	paused = true
	await process_frame
	await process_frame
	check("pause clears both heart voices and timer", silent_heart())
	var before: int = beats
	manager._process(10)
	check("pause emits no heartbeat", before == beats)
	paused = false
	manager.set_process(true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	before = beats
	manager.set_paranoia(100)
	await create_timer(0.5).timeout
	check("return to menu stops gameplay pulse", beats == before and silent_heart() and not manager.is_active)
	check("return to menu restarts rain", sound._rain_player.playing)
	manager.is_active = true
	sound.play_heartbeat_pulse(172,1)
	manager._trigger_heartbeat()
	check("scene gate rejects pulse even when accidentally activated", beats == before and silent_heart())
	manager.is_active = false
	print("RECORDED_AUDIO_CHECK checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
