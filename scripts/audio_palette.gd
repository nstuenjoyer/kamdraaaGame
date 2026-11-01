extends RefCounted

# Procedural close-miked foley: filtered contact noise, damped resonances,
# and rounded envelopes. No square waves or instantaneous digital attacks.
static func make(kind: String, variant: int = 0, sample_rate: int = 22050) -> AudioStreamWAV:
	var duration: float = 0.20
	var frequency: float = 160.0
	var body: float = 0.12
	var noise: float = 0.7
	var smoothing: float = 0.12
	var decay: float = 25.0
	var peak: float = 0.24
	match kind:
		"wood":
			duration = 0.19
			frequency = 115.0
			body = 0.20
			decay = 30.0
		"concrete":
			duration = 0.15
			frequency = 78.0
			body = 0.08
			smoothing = 0.23
			decay = 38.0
		"paper":
			duration = 0.30
			body = 0.0
			smoothing = 0.30
			decay = 9.0
		"glass":
			duration = 0.28
			frequency = 620.0
			body = 0.08
			smoothing = 0.20
			decay = 22.0
		"metal":
			duration = 0.28
			frequency = 290.0
			body = 0.14
			decay = 24.0
		"plastic":
			duration = 0.16
			frequency = 210.0
			body = 0.12
			decay = 38.0
		"tick", "hover":
			duration = 0.055
			body = 0.0
			decay = 65.0
			peak = 0.10
		"click", "cancel":
			duration = 0.09
			frequency = 190.0
			body = 0.06
			decay = 42.0
			peak = 0.16
		"notice", "success", "failure":
			duration = 0.38
			frequency = 280.0 if kind != "failure" else 185.0
			body = 0.45
			noise = 0.08
			decay = 12.0
			peak = 0.18
		"heartbeat":
			duration = 0.40
			frequency = 57.0
			body = 0.55
			noise = 0.12
			smoothing = 0.06
			decay = 25.0
		"car":
			duration = 3.4
			frequency = 65.0
			body = 0.05
			smoothing = 0.025
			decay = 0.8
	var count: int = int(duration * sample_rate)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1009 + variant * 7919 + int(kind.hash())
	var low: float = 0.0
	var smooth: float = 0.0
	var maximum: float = 0.001
	frequency *= 1.0 + float(variant - 2) * 0.012
	for index: int in range(count):
		var t: float = float(index) / sample_rate
		var progress: float = float(index) / float(count - 1)
		low += smoothing * (random.randf_range(-1.0, 1.0) - low)
		smooth += 0.45 * (low - smooth)
		var envelope: float = (1.0 - exp(-t / 0.007)) * exp(-t * decay)
		var resonance: float = sin(t * frequency * TAU) + 0.25 * sin(t * frequency * 1.43 * TAU)
		var contact: float = smooth * noise + resonance * body
		var delay: float = 0.045 if kind != "heartbeat" else 0.14
		if t > delay:
			var second_t: float = t - delay
			contact += smooth * noise * (1.0 - exp(-second_t / 0.012)) * exp(-second_t * decay) * 0.4
		if kind == "heartbeat" and t > delay:
			contact += sin((t - delay) * frequency * TAU) * exp(-(t - delay) * 35.0) * 0.32
		if kind == "car":
			envelope = pow(sin(progress * PI), 2.0)
		var edge: float = smoothstep(0.0, 0.012, t) * (1.0 - smoothstep(duration - 0.045, duration, t))
		samples[index] = contact * envelope * edge
		maximum = maxf(maximum, absf(samples[index]))
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for index: int in range(count):
		data.encode_s16(index * 2, int(clampf(samples[index] * peak / maximum, -0.9, 0.9) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func phone_ring(sample_rate: int = 22050) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_rate * 3 * 2)
	for index: int in range(sample_rate * 3):
		var t: float = float(index) / sample_rate
		var burst: float = t if t < 0.48 else t - 0.72
		var envelope: float = 0.0
		if burst >= 0.0 and burst <= 0.48:
			envelope = smoothstep(0.0, 0.025, burst) * (1.0 - smoothstep(0.34, 0.48, burst))
		var bell: float = sin(t * 620.0 * TAU) * 0.65 + sin(t * 815.0 * TAU) * 0.25
		var pulse: float = 0.7 + 0.3 * sin(t * 16.0 * TAU)
		data.encode_s16(index * 2, int(bell * envelope * pulse * 0.24 * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_rate * 3
	return stream
