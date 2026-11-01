extends Node

const Palette = preload("res://scripts/audio_palette.gd")
var _surface_steps: Dictionary = {}
var _material_sounds: Dictionary = {}
var _sfx_voices: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _last_tick: int = -1000

# Менеджер процедурных звуковых эффектов (SoundManager)
# Кэширует мягкую Foley-палитру материалов и ограничивает повторение эффектов.

var _click_stream: AudioStreamWAV
var _hover_stream: AudioStreamWAV
var _save_stream: AudioStreamWAV
var _cancel_stream: AudioStreamWAV
var _paranoia_stream: AudioStreamWAV
var _footstep_left_stream: AudioStreamWAV
var _footstep_right_stream: AudioStreamWAV
var _footstep_variants: Array[AudioStreamWAV] = []
var _last_footstep_variant: int = -1
var _is_left_foot: bool = false
var _wall_bump_stream: AudioStreamWAV
var _interact_stream: AudioStreamWAV
var _phone_ring_stream: AudioStreamWAV
var _phone_pickup_stream: AudioStreamWAV
var _dialogue_advance_stream: AudioStreamWAV
var _door_unlock_stream: AudioStreamWAV
var _bg_music_stream: AudioStreamWAV
var _clue_stream: AudioStreamWAV
var _paper_stream: AudioStreamWAV
var _typewriter_stream: AudioStreamWAV
var _pills_stream: AudioStreamWAV
var _deduction_success_stream: AudioStreamWAV
var _deduction_fail_stream: AudioStreamWAV
var _clue_pin_stream: AudioStreamWAV
var _flashlight_on_stream: AudioStreamWAV
var _flashlight_off_stream: AudioStreamWAV
var _car_pass_stream: AudioStreamWAV

var _player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _phone_ring_player: AudioStreamPlayer
var _typewriter_player: AudioStreamPlayer
var _heart_s1_player: AudioStreamPlayer
var _heart_s2_player: AudioStreamPlayer
var _heart_s2_stream: AudioStreamWAV
var _pending_dub: float = -1.0
var _rain_player: AudioStreamPlayer
var _rain_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	add_child(_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -16.0
	_music_player.bus = &"Music" if AudioServer.get_bus_index(&"Music") != -1 else &"Master"
	add_child(_music_player)

	_phone_ring_player = AudioStreamPlayer.new()
	_phone_ring_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	_phone_ring_player.volume_db = -13.0
	add_child(_phone_ring_player)

	_typewriter_player = AudioStreamPlayer.new()
	_typewriter_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	_typewriter_player.volume_db = -27.0
	add_child(_typewriter_player)

	_generate_procedural_sounds()
	for index: int in 2:
		var heart: AudioStreamPlayer = AudioStreamPlayer.new()
		heart.bus = _player.bus
		add_child(heart)
		if index == 0: _heart_s1_player = heart
		else: _heart_s2_player = heart
	_heart_s1_player.stream = _paranoia_stream
	_heart_s2_stream = load("res://assets/audio/heartbeat_s2.wav")
	_heart_s2_player.stream = _heart_s2_stream
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = _player.bus
	var rain: AudioStreamWAV = (load("res://assets/audio/menu_rain.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	var rain_frames: int = roundi(rain.get_length() * rain.mix_rate)
	rain.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rain.loop_begin = 0
	rain.loop_end = rain_frames
	_rain_player.stream = rain
	_rain_player.volume_db = -60.0
	add_child(_rain_player)

func _generate_procedural_sounds() -> void:
	_click_stream = Palette.make("click", 0)
	_hover_stream = Palette.make("hover", 1)
	_save_stream = Palette.make("notice", 2)
	_cancel_stream = Palette.make("cancel", 3)
	_paranoia_stream = load("res://assets/audio/heartbeat_s1.wav")
	_wall_bump_stream = Palette.make("wood", 5)
	_interact_stream = Palette.make("plastic", 6)
	_phone_pickup_stream = Palette.make("plastic", 7)
	_dialogue_advance_stream = Palette.make("click", 8)
	_door_unlock_stream = Palette.make("metal", 9)
	_clue_stream = Palette.make("notice", 10)
	_paper_stream = Palette.make("paper", 11)
	_typewriter_stream = Palette.make("tick", 12)
	_pills_stream = Palette.make("plastic", 13)
	_deduction_success_stream = Palette.make("success", 14)
	_deduction_fail_stream = Palette.make("failure", 15)
	_clue_pin_stream = Palette.make("plastic", 16)
	_flashlight_on_stream = Palette.make("plastic", 17)
	_flashlight_off_stream = Palette.make("plastic", 18)
	_car_pass_stream = Palette.make("car", 19)
	for material_name: String in ["wood", "metal", "glass", "paper", "plastic"]:
		_material_sounds[material_name] = Palette.make(material_name, 3)
	_phone_ring_stream = Palette.phone_ring()
	_bg_music_stream = _create_looping_music(8.0, 22050)
	for surface: String in ["wood", "concrete"]:
		var variants: Array[AudioStreamWAV] = []
		for variant: int in range(6):
			variants.append(Palette.make(surface, variant))
		_surface_steps[surface] = variants
	_footstep_variants.assign(_surface_steps["wood"])
	_footstep_left_stream = _footstep_variants[0]
	_footstep_right_stream = _footstep_variants[1]
	for index: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
		add_child(voice)
		_sfx_voices.append(voice)

func _create_looping_music(duration: float, sample_rate: int) -> AudioStreamWAV:
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var base_freq: float = 1.0 / duration # 0.125 Hz
	var d2: float = base_freq * 584.0     # ~73.0 Hz (D2 bass root)
	var a2: float = base_freq * 880.0     # ~110.0 Hz (A2)
	var d3: float = base_freq * 1168.0    # ~146.0 Hz (D3)
	var f3: float = base_freq * 1392.0    # ~174.0 Hz (F3)
	var a3: float = base_freq * 1760.0    # ~220.0 Hz (A3)
	var c4: float = base_freq * 2088.0    # ~261.0 Hz (C4)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)

		var lfo1: float = (sin(t * base_freq * TAU) + 1.0) * 0.5
		var lfo2: float = (sin(t * base_freq * 2.0 * TAU) + 1.0) * 0.5
		var lfo4: float = (sin(t * base_freq * 4.0 * TAU) + 1.0) * 0.5

		# 1. Тёмный нуарный суб-бас
		var bass: float = sin(t * d2 * TAU) * 0.45 * (0.8 + 0.2 * lfo2)

		# 2. Тёплый аналоговый пэд (D minor 7)
		var pad_d: float = sin(t * d3 * TAU) * 0.2
		var pad_f: float = sin(t * f3 * TAU) * 0.18 * (0.5 + 0.5 * lfo1)
		var pad_a: float = sin(t * a3 * TAU) * 0.16 * (0.4 + 0.6 * lfo2)
		var pad_c: float = sin(t * c4 * TAU) * 0.14 * (0.3 + 0.7 * lfo4)
		var pad: float = (pad_d + pad_f + pad_a + pad_c) * (0.7 + 0.3 * lfo1)

		# 3. Мягкая хорусовая гармоника
		var chorus: float = sin(t * a2 * TAU) * 0.18

		# 4. Лоу-фай виниловое дыхание
		var vinyl: float = sin(t * base_freq * 32.0 * TAU) * 0.04 * (sin(t * 1800.0 * TAU) * 0.1)

		var mixed: float = (bass + pad + chorus + vinyl) * 0.42
		var sample_int: int = clampi(int(mixed * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream

func start_bg_music() -> void:
	if not _music_player:
		return
	if not _music_player.playing and _bg_music_stream:
		_music_player.stream = _bg_music_stream
		_music_player.play()

func stop_bg_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()

func start_phone_ringing() -> void:
	if not _phone_ring_player:
		return
	if not _phone_ring_player.playing and _phone_ring_stream:
		_phone_ring_player.stream = _phone_ring_stream
		_phone_ring_player.play()

func stop_phone_ringing() -> void:
	if _phone_ring_player and _phone_ring_player.playing:
		_phone_ring_player.stop()

func is_phone_ringing() -> bool:
	return _phone_ring_player != null and _phone_ring_player.playing

func play_click() -> void:
	if _click_stream:
		_play_stream_pitched(_click_stream, 1.0, -13.0)

func play_hover() -> void:
	if _hover_stream:
		_play_stream_pitched(_hover_stream, 1.0, -18.0)

func play_save() -> void:
	if _save_stream:
		_play_stream(_save_stream)

func play_cancel() -> void:
	if _cancel_stream:
		_play_stream(_cancel_stream)

func play_paranoia_pulse() -> void:
	play_heartbeat_pulse(90, 0.5)

func play_heartbeat_pulse(bpm: int, paranoia_factor: float) -> void:
	if not gameplay_audio_allowed() or not _heart_s1_player:
		return
	# Recorded S1/S2 retain their original pitch. Only spacing and level change.
	# Dedicated players prevent busy Foley voices or duplicate suppression from
	# swallowing a beat. Even at 190 BPM each transient finishes before its repeat.
	if _heart_s1_player.playing: return
	var volume: float = lerpf(-26.0, -15.0, clampf(paranoia_factor, 0.0, 1.0))
	_heart_s1_player.volume_db = volume
	_heart_s2_player.volume_db = volume
	_heart_s1_player.pitch_scale = 1.0
	_heart_s2_player.pitch_scale = 1.0
	_heart_s1_player.play()
	_pending_dub = clampf((60.0 / clampf(float(bpm), 45.0, 190.0)) * 0.27, 0.09, 0.20)

func gameplay_audio_allowed() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null or get_tree().paused: return false
	var manager: Node = get_node_or_null("/root/ParanoiaManager")
	return manager != null and manager.is_active and (scene.has_method("export_chapter_save") or scene.scene_file_path == "res://scenes/main.tscn")

func stop_heartbeat() -> void:
	_pending_dub = -1.0
	for heart: AudioStreamPlayer in [_heart_s1_player, _heart_s2_player]:
		if is_instance_valid(heart) and heart.playing: heart.stop()

func start_menu_rain() -> void:
	stop_heartbeat()
	stop_bg_music()
	if not _rain_player: return
	if _rain_tween and _rain_tween.is_valid(): _rain_tween.kill()
	if not _rain_player.playing:
		_rain_player.volume_db = -60.0
		_rain_player.play()
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", -16.0, 0.9)

func stop_menu_rain() -> void:
	if not _rain_player: return
	if _rain_tween and _rain_tween.is_valid(): _rain_tween.kill()
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", -60.0, 0.25)
	_rain_tween.tween_callback(_rain_player.stop)

func _process(delta: float) -> void:
	if not gameplay_audio_allowed():
		stop_heartbeat()
		return
	if _pending_dub >= 0.0:
		_pending_dub -= delta
		if _pending_dub < 0.0: _heart_s2_player.play()

func play_footstep(surface: String = "wood", volume_offset: float = 0.0) -> void:
	var variants: Array = _surface_steps.get(surface, _footstep_variants)
	var variant: int = randi_range(0, 2) * 2 + (0 if _is_left_foot else 1)
	if variant == _last_footstep_variant:
		variant = (variant + 2) % _footstep_variants.size()
	_last_footstep_variant = variant
	var stream: AudioStreamWAV = variants[variant]
	_is_left_foot = not _is_left_foot
	if stream:
		_play_stream_pitched(stream, randf_range(0.98, 1.02), randf_range(-8.5, -7.0) + volume_offset)

func play_wall_bump() -> void:
	if _wall_bump_stream:
		_play_stream_pitched(_wall_bump_stream, randf_range(0.98, 1.02), -10.0)

func play_interact() -> void:
	if _interact_stream:
		_play_stream(_interact_stream)

func play_pills_taken() -> void:
	if _pills_stream:
		_play_stream(_pills_stream)

func play_phone_pickup() -> void:
	stop_phone_ringing()
	if _phone_pickup_stream:
		_play_stream_pitched(_phone_pickup_stream, 1.0, -9.0)

func play_dialogue_advance() -> void:
	if _dialogue_advance_stream:
		_play_stream_pitched(_dialogue_advance_stream, randf_range(0.99, 1.01), -15.0)

func play_door_unlock() -> void:
	if _door_unlock_stream:
		_play_stream(_door_unlock_stream)

func play_clue_found() -> void:
	if _clue_stream:
		_play_stream(_clue_stream)

func play_paper_rustle() -> void:
	if _paper_stream:
		_play_stream_pitched(_paper_stream, randf_range(0.98, 1.02), -10.0)

func play_typewriter_tick() -> void:
	if not _typewriter_player or not _typewriter_stream:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_tick < 85:
		return
	_last_tick = now
	_typewriter_player.stream = _typewriter_stream
	_typewriter_player.pitch_scale = randf_range(0.98, 1.02)
	_typewriter_player.play()

func play_deduction_success() -> void:
	if _deduction_success_stream:
		_play_stream(_deduction_success_stream)

func play_deduction_fail() -> void:
	if _deduction_fail_stream:
		_play_stream(_deduction_fail_stream)

func play_clue_pin() -> void:
	if _clue_pin_stream:
		_play_stream_pitched(_clue_pin_stream, randf_range(0.95, 1.05), 0.0)

func play_flashlight_toggle(is_on: bool) -> void:
	var stream: AudioStreamWAV = _flashlight_on_stream if is_on else _flashlight_off_stream
	if stream:
		_play_stream_pitched(stream, randf_range(0.96, 1.04), 0.0)

func play_car_pass() -> void:
	if _car_pass_stream:
		_play_stream_pitched(_car_pass_stream, randf_range(0.95, 1.05), -4.0)

func play_material_interact(material_name: String) -> void:
	var kind: String = material_name if material_name in ["wood", "metal", "glass", "paper", "plastic"] else "plastic"
	_play_stream_pitched(_material_sounds[kind], randf_range(0.98, 1.02), -9.0)

func _play_stream(stream: AudioStreamWAV) -> void:
	_play_stream_pitched(stream, 1.0, -9.0)

func _play_stream_pitched(stream: AudioStreamWAV, pitch: float = 1.0, volume_db_offset: float = -9.0) -> void:
	var key: int = stream.get_instance_id()
	var now: int = Time.get_ticks_msec()
	# A dialogue advance may be requested by both input and line transition.
	if now - int(_last_played.get(key, -1000)) < 100:
		return
	for voice: AudioStreamPlayer in _sfx_voices:
		if not voice.playing:
			_last_played[key] = now
			voice.stream = stream
			voice.pitch_scale = pitch
			voice.volume_db = minf(volume_db_offset, -5.0)
			voice.play()
			return

func _exit_tree() -> void:
	# Release active mixer playbacks before the scene tree and AudioServer shut down.
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
