extends Node

# Менеджер процедурных звуковых эффектов (SoundManager)
# Генерирует и воспроизводит аккуратные ретро-неонуарные UI звуки без внешних файлов

var _click_stream: AudioStreamWAV
var _hover_stream: AudioStreamWAV
var _save_stream: AudioStreamWAV
var _cancel_stream: AudioStreamWAV
var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	add_child(_player)
	_generate_procedural_sounds()

func _generate_procedural_sounds() -> void:
	_click_stream = _create_sound(0.04, 22050, func(t: float, progress: float) -> float:
		var freq: float = lerpf(880.0, 440.0, progress)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.35
	)
	
	_hover_stream = _create_sound(0.02, 22050, func(t: float, progress: float) -> float:
		var freq: float = 1200.0
		var envelope: float = (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.12
	)
	
	_save_stream = _create_sound(0.18, 22050, func(t: float, progress: float) -> float:
		var freq: float = 523.25 if progress < 0.5 else 659.25 # C5 -> E5
		var sub_progress: float = (progress if progress < 0.5 else progress - 0.5) * 2.0
		var envelope: float = (1.0 - sub_progress)
		return (sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)) * envelope * 0.3
	)

	_cancel_stream = _create_sound(0.05, 22050, func(t: float, progress: float) -> float:
		var freq: float = lerpf(350.0, 220.0, progress)
		var envelope: float = (1.0 - progress)
		return sin(t * freq * TAU) * envelope * 0.25
	)

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

func _play_stream(stream: AudioStreamWAV) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
