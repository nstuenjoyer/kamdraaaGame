extends Node

# Менеджер процедурных звуковых эффектов (SoundManager)
# Генерирует и воспроизводит аккуратные ретро-неонуарные UI звуки, шаги, телефон и переключение диалогов без внешних файлов

var _click_stream: AudioStreamWAV
var _hover_stream: AudioStreamWAV
var _save_stream: AudioStreamWAV
var _cancel_stream: AudioStreamWAV
var _paranoia_stream: AudioStreamWAV
var _footstep_left_stream: AudioStreamWAV
var _footstep_right_stream: AudioStreamWAV
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

var _player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _phone_ring_player: AudioStreamPlayer
var _typewriter_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	add_child(_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music" if AudioServer.get_bus_index(&"Music") != -1 else &"Master"
	add_child(_music_player)

	_phone_ring_player = AudioStreamPlayer.new()
	_phone_ring_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	_phone_ring_player.volume_db = -13.0
	add_child(_phone_ring_player)

	_typewriter_player = AudioStreamPlayer.new()
	_typewriter_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	_typewriter_player.volume_db = -19.0
	add_child(_typewriter_player)

	_generate_procedural_sounds()
	start_bg_music()

func _generate_procedural_sounds() -> void:
	# 1. Клик по кнопкам интерфейса
	_click_stream = _create_sound(0.04, 22050, func(t: float, progress: float) -> float:
		var freq: float = lerpf(880.0, 440.0, progress)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.35
	)
	
	# 2. Наведение на кнопки
	_hover_stream = _create_sound(0.02, 22050, func(t: float, progress: float) -> float:
		var freq: float = 1200.0
		var envelope: float = (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.12
	)
	
	# 3. Сохранение
	_save_stream = _create_sound(0.18, 22050, func(t: float, progress: float) -> float:
		var freq: float = 523.25 if progress < 0.5 else 659.25 # C5 -> E5
		var sub_progress: float = (progress if progress < 0.5 else progress - 0.5) * 2.0
		var envelope: float = (1.0 - sub_progress)
		return (sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)) * envelope * 0.3
	)

	# 4. Отмена / закрытие
	_cancel_stream = _create_sound(0.05, 22050, func(t: float, progress: float) -> float:
		var freq: float = lerpf(350.0, 220.0, progress)
		var envelope: float = (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.25
	)

	# 5. Импульс паранойи (глухой тревожный стук сердца)
	_paranoia_stream = _create_sound(0.35, 22050, func(t: float, progress: float) -> float:
		var freq: float = lerpf(65.0, 44.0, progress)
		var p1: float = maxf(0.0, 1.0 - absf(progress - 0.1) * 10.0)
		var p2: float = maxf(0.0, 1.0 - absf(progress - 0.23) * 10.0)
		var env: float = p1 * 0.85 + p2 * 0.65
		var bass: float = sin(t * freq * TAU)
		var noise: float = sin(t * 190.0 * TAU) * 0.12 * p1
		return (bass + noise) * env * 0.45
	)

	# 6. Реалистичные шаги (обувь по деревянному полу / паркету: каблук + подошва + фрикционный шум)
	_footstep_left_stream = _create_footstep(true, 22050)
	_footstep_right_stream = _create_footstep(false, 22050)

	# 7. Врезание в стену (глухой увесистый удар с сотрясением)
	_wall_bump_stream = _create_sound(0.16, 22050, func(t: float, progress: float) -> float:
		var env: float = (1.0 - progress) * (1.0 - progress)
		var freq: float = lerpf(110.0, 48.0, progress)
		var thud: float = sin(t * freq * TAU)
		var sub: float = sin(t * 55.0 * TAU) * 0.5
		var click: float = sin(t * 600.0 * TAU) * 0.25 if progress < 0.15 else 0.0
		return (thud + sub + click) * env * 0.55
	)

	# 8. Тактильное взаимодействие с объектами
	_interact_stream = _create_sound(0.09, 22050, func(t: float, progress: float) -> float:
		var env: float = (1.0 - progress)
		var freq: float = lerpf(680.0, 1150.0, progress)
		var tone: float = sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)
		return tone * env * 0.28
	)

	# 8.1. Прием седативных таблеток / глоток воды
	_pills_stream = _create_sound(0.24, 22050, func(t: float, progress: float) -> float:
		var click_env: float = maxf(0.0, 1.0 - absf(progress - 0.1) * 16.0)
		var click: float = sin(t * 920.0 * TAU) * click_env
		var gulp_env: float = maxf(0.0, 1.0 - absf(progress - 0.5) * 4.0)
		var gulp: float = sin(t * lerpf(260.0, 180.0, progress) * TAU) * gulp_env * 0.7
		return (click * 0.35 + gulp * 0.65) * 0.38
	)

	# 9. Тихий фоновый звон стационарного телефона (цикличный ретро-звонок)
	_phone_ring_stream = _create_phone_ring(22050)

	# 10. Снятие телефонной трубки (механический щелчок рычага + открытая линия / мембрана)
	_phone_pickup_stream = _create_phone_pickup(22050)

	# 11. Звук переключения диалога (тактильный щелчок механической пишущей машинки)
	_dialogue_advance_stream = _create_dialogue_advance(22050)

	# 12. Разблокировка электрозамка двери
	_door_unlock_stream = _create_sound(0.3, 22050, func(t: float, progress: float) -> float:
		var env: float = 1.0 - progress
		var beep: float = sin(t * 1320.0 * TAU) * 0.3 if progress < 0.12 else 0.0
		var servo: float = sin(t * 180.0 * TAU) * 0.25 * env
		var latch_env: float = maxf(0.0, 1.0 - absf(progress - 0.18) * 8.0)
		var latch: float = (sin(t * 320.0 * TAU) + sin(t * 740.0 * TAU) * 0.5) * latch_env * 0.5
		return (beep + servo + latch) * env * 0.5
	)

	# 13. Звук обнаружения важной сюжетной улики (загадочный перезвон колокольчиков)
	_clue_stream = _create_sound(0.55, 22050, func(t: float, progress: float) -> float:
		var env1: float = exp(-t * 7.0)
		var env2: float = exp(-maxf(0.0, t - 0.12) * 5.5) if t >= 0.12 else 0.0
		var tone1: float = (sin(t * 587.33 * TAU) + sin(t * 1174.66 * TAU) * 0.3) * env1
		var tone2: float = (sin((t - 0.12) * 880.0 * TAU) + sin((t - 0.12) * 1760.0 * TAU) * 0.25) * env2
		return (tone1 * 0.28 + tone2 * 0.35) * (1.0 - progress)
	)

	# 14. Шелест бумаги / осмотр чека
	_paper_stream = _create_sound(0.16, 22050, func(t: float, progress: float) -> float:
		var lcg: int = int(t * 9876543.0) & 0x7fffffff
		var noise: float = (float(lcg % 20001) / 10000.0) - 1.0
		var envelope: float = sin(progress * PI)
		return noise * envelope * 0.25
	)

	# 15. Механический стук клавиши пишущей машинки
	_typewriter_stream = _create_sound(0.026, 22050, func(t: float, progress: float) -> float:
		var env: float = (1.0 - progress) * (1.0 - progress)
		var snap: float = sin(t * 1380.0 * TAU) * env
		var noise: float = ((float((int(t * 918273.0)) % 1000) / 500.0) - 1.0) * env * 0.4
		return (snap * 0.5 + noise * 0.3) * 0.22
	)

	# 16. Бесшовная неонуарная эмбиент-музыка (8.0 сек. идеальный математический луп)
	_bg_music_stream = _create_looping_music(8.0, 22050)

func _create_sound(duration: float, sample_rate: int, generator: Callable) -> AudioStreamWAV:
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var sample_f: float = generator.call(t, progress)
		var sample_int: int = clampi(int(sample_f * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)
		
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _create_footstep(is_left: bool, sample_rate: int = 22050) -> AudioStreamWAV:
	var duration: float = 0.088
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var lcg: int = 48271 if is_left else 69621
	var base_freq: float = 106.0 if is_left else 118.0
	var toe_delay: float = 0.021 if is_left else 0.027
	var prev_noise: float = 0.0

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		lcg = (lcg * 1103515245 + 12345) & 0x7fffffff
		var raw_noise: float = (float(lcg % 20001) / 10000.0) - 1.0
		# Высокочастотный шум трения подошвы о покрытие (паркет/ламинат)
		var friction: float = raw_noise - prev_noise * 0.68
		prev_noise = raw_noise

		# 1. Каблук / пятка (Heel strike)
		var heel_env: float = exp(-t * 85.0)
		var heel_knock: float = sin(t * base_freq * TAU) * heel_env
		var heel_scuff: float = friction * heel_env * 0.48

		# 2. Носок / подошва (Toe slap с физической микро-задержкой)
		var toe_t: float = t - toe_delay
		var toe_knock: float = 0.0
		var toe_scuff: float = 0.0
		if toe_t > 0.0:
			var toe_env: float = exp(-toe_t * 92.0)
			toe_knock = sin(toe_t * (base_freq * 1.32) * TAU) * toe_env * 0.45
			toe_scuff = friction * toe_env * 0.38

		var sample_f: float = (heel_knock * 0.58 + heel_scuff + toe_knock * 0.38 + toe_scuff) * 0.72
		var sample_int: int = clampi(int(sample_f * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _create_phone_ring(sample_rate: int = 22050) -> AudioStreamWAV:
	# Двойной ретро-звонок стационарного аппарата (3.2 сек. цикл)
	var duration: float = 3.2
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var f1: float = 780.0
	var f2: float = 1040.0
	var f_harmonic: float = 2300.0

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var sample_f: float = 0.0

		# Два импульса звонка (0..0.42 сек и 0.62..1.04 сек)
		var in_burst_1: bool = (t >= 0.0 and t < 0.42)
		var in_burst_2: bool = (t >= 0.62 and t < 1.04)

		if in_burst_1 or in_burst_2:
			var burst_t: float = t if in_burst_1 else (t - 0.62)
			var clapper: float = (sin(burst_t * 18.0 * TAU) + 1.0) * 0.5
			var bell: float = sin(t * f1 * TAU) * 0.5 + sin(t * f2 * TAU) * 0.4 + sin(t * f_harmonic * TAU) * 0.12
			sample_f = bell * clapper * 0.32
		elif t >= 1.04 and t < 1.35:
			# Мягкое послезвучание чашечек звонка
			var ringout_env: float = exp(-(t - 1.04) * 9.0)
			sample_f = (sin(t * f1 * TAU) * 0.3 + sin(t * f2 * TAU) * 0.25) * ringout_env * 0.25
		else:
			sample_f = 0.0

		var sample_int: int = clampi(int(sample_f * 32767.0), -32768, 32767)
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

func _create_phone_pickup(sample_rate: int = 22050) -> AudioStreamWAV:
	# Снятие трубки: щелчок рычага + открывающаяся телефонная линия / гудок
	var duration: float = 0.34
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var lcg: int = 918273
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		lcg = (lcg * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(lcg % 20001) / 10000.0) - 1.0

		# 1. Первый щелчок — снятие трубки с пластикового корпуса
		var clack1_env: float = exp(-t * 90.0)
		var clack1: float = (sin(t * 880.0 * TAU) * 0.55 + sin(t * 1800.0 * TAU) * 0.4 + noise * 0.3) * clack1_env

		# 2. Второй металлический щелчок — подъем подпружиненного рычага (t ~ 0.038s)
		var t2: float = t - 0.038
		var clack2: float = 0.0
		if t2 > 0.0:
			var clack2_env: float = exp(-t2 * 105.0)
			clack2 = (sin(t2 * 1420.0 * TAU) * 0.5 + sin(t2 * 2850.0 * TAU) * 0.35 + noise * 0.3) * clack2_env

		# 3. Линия оживает — лёгкий щелчок коммутации и фон мембраны / советский гудок 425 Гц
		var t3: float = t - 0.065
		var line_tone: float = 0.0
		if t3 > 0.0:
			var line_env: float = (1.0 - t3 / (duration - 0.065)) * 0.35
			var dial_tone: float = sin(t3 * 425.0 * TAU) * 0.32
			var hiss: float = noise * 0.08
			line_tone = (dial_tone + hiss) * line_env

		var mixed: float = (clack1 * 0.6 + clack2 * 0.5 + line_tone * 0.7) * 0.65
		var sample_int: int = clampi(int(mixed * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _create_dialogue_advance(sample_rate: int = 22050) -> AudioStreamWAV:
	# Тактильный звук переключения диалога (пишущая машинка / мягкий щелчок клавиши)
	var duration: float = 0.045
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	var lcg: int = 543210
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		lcg = (lcg * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(lcg % 20001) / 10000.0) - 1.0

		var env: float = exp(-t * 95.0)
		var snap: float = sin(t * 1680.0 * TAU) * 0.5
		var body: float = sin(t * 540.0 * TAU) * 0.45
		var click_noise: float = noise * 0.35 * exp(-t * 135.0)
		var mixed: float = (snap + body + click_noise) * env * 0.45

		var sample_int: int = clampi(int(mixed * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_int)

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

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
		_play_stream(_click_stream)

func play_hover() -> void:
	if _hover_stream:
		_play_stream(_hover_stream)

func play_save() -> void:
	if _save_stream:
		_play_stream(_save_stream)

func play_cancel() -> void:
	if _cancel_stream:
		_play_stream(_cancel_stream)

func play_paranoia_pulse() -> void:
	if _paranoia_stream:
		_play_stream(_paranoia_stream)

func play_heartbeat_pulse(bpm: int, paranoia_factor: float) -> void:
	if not _paranoia_stream:
		return
	# Плавная модуляция высоты тона в зависимости от частоты ударов
	var pitch: float = lerpf(0.92, 1.26, clampf((float(bpm) - 60.0) / 115.0, 0.0, 1.0))
	# Громкость: от деликатного тихого стука в покое (-9.0 dB) до тревожного глухого удара в панике (+2.5 dB)
	var volume_offset: float = lerpf(-9.0, 2.5, clampf(paranoia_factor, 0.0, 1.0))
	_play_stream_pitched(_paranoia_stream, pitch, volume_offset)

func play_footstep() -> void:
	var stream: AudioStreamWAV = _footstep_left_stream if _is_left_foot else _footstep_right_stream
	_is_left_foot = not _is_left_foot
	if stream:
		_play_stream_pitched(stream, randf_range(0.96, 1.05), -2.0)

func play_wall_bump() -> void:
	if _wall_bump_stream:
		_play_stream_pitched(_wall_bump_stream, randf_range(0.95, 1.05), 1.0)

func play_interact() -> void:
	if _interact_stream:
		_play_stream(_interact_stream)

func play_pills_taken() -> void:
	if _pills_stream:
		_play_stream(_pills_stream)

func play_phone_pickup() -> void:
	stop_phone_ringing()
	if _phone_pickup_stream:
		_play_stream_pitched(_phone_pickup_stream, 1.0, 1.0)

func play_dialogue_advance() -> void:
	if _dialogue_advance_stream:
		_play_stream_pitched(_dialogue_advance_stream, randf_range(0.96, 1.06), -6.0)

func play_door_unlock() -> void:
	if _door_unlock_stream:
		_play_stream(_door_unlock_stream)

func play_clue_found() -> void:
	if _clue_stream:
		_play_stream(_clue_stream)

func play_paper_rustle() -> void:
	if _paper_stream:
		_play_stream_pitched(_paper_stream, randf_range(0.95, 1.08), 2.0)

func play_typewriter_tick() -> void:
	if not _typewriter_player or not _typewriter_stream:
		return
	_typewriter_player.stream = _typewriter_stream
	_typewriter_player.pitch_scale = randf_range(0.92, 1.14)
	_typewriter_player.play()

func _play_stream(stream: AudioStreamWAV) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func _play_stream_pitched(stream: AudioStreamWAV, pitch: float = 1.0, volume_db_offset: float = 0.0) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db_offset
	player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
