"""Cut the user's steps-2.mp3 after decoding with decode_user_steps.gd.

Standard library only. Gentle denoising/EQ and transient softening; no pitch shift.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/footsteps_user'
with wave.open(str(ROOT / '.godot/user_steps_decoded.wav')) as source:
    rate = source.getframerate()
    samples = array.array('h', source.readframes(source.getnframes()))
hop = round(rate * .01)
energy = [math.sqrt(sum(v * v for v in samples[i:i + hop]) / len(samples[i:i + hop]))
          for i in range(0, len(samples), hop)]
events = []
for i in sorted(range(len(energy)), key=lambda i: energy[i], reverse=True):
    if energy[i] < max(energy) * .14:
        break
    if all(abs(i - j) >= 28 for j in events):
        events.append(i)
events.sort()
assert len(events) == 6, f'Review changed source: expected 6 steps, got {events}'
# Estimate background from the quietest sections, not from the footfalls.
noise_floor = max(.0008, sorted(energy)[round(len(energy) * .15)] / 32768 * 2.5)
highpass_alpha = math.exp(-2 * math.pi * 85 / rate)
lowpass_alpha = 1 - math.exp(-2 * math.pi * 2400 / rate)
envelope_alpha = 1 - math.exp(-1 / (rate * .012))
previous = high = low1 = low2 = envelope = 0.0
gate = 0.08
processed = []
for sample in samples:
    value = sample / 32768
    high = highpass_alpha * (high + value - previous)
    previous = value
    low1 += lowpass_alpha * (high - low1)
    low2 += lowpass_alpha * (low1 - low2)
    envelope += envelope_alpha * (low2 * low2 - envelope)
    target = min(1.0, max(.08, (math.sqrt(max(0, envelope)) - noise_floor) / (noise_floor * 3)))
    smoothing = 1 - math.exp(-1 / (rate * (.006 if target > gate else .050)))
    gate += smoothing * (target - gate)
    # Soft knee rounds isolated clicks rather than adding hard clipping.
    processed.append(.14 * math.tanh(low2 / .14) * gate)
gain = .22 / max(abs(v) for v in processed)


def save(path, data):
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(data.tobytes())


manifest = []
preview = array.array('h', [0]) * round(rate * 3.7)
for index, event in enumerate(events):
    peak_time = event * hop / rate
    start = max(0, round((peak_time - .16) * rate))
    end = min(len(samples), round((peak_time + .35) * rate))
    if index:
        start = max(start, round((events[index - 1] + event) * hop / 2))
    if index + 1 < len(events):
        end = min(end, round((events[index + 1] + event) * hop / 2))
    clip = processed[start:end]
    dc = sum(clip) / len(clip)
    fade = round(rate * .016)
    clip = array.array('h', [round((v - dc) * gain * 32767 * min(1, n / fade, (len(clip) - n - 1) / fade))
                             for n, v in enumerate(clip)])
    path = OUT / f'step_{index:02d}.wav'
    save(path, clip)
    offset = round(index * .6 * rate)
    for n, v in enumerate(clip):
        if offset + n < len(preview):
            preview[offset + n] = round(v * 10 ** (-18 / 20))
    manifest.append({'file': path.name, 'source_start': start / rate,
                     'duration': len(clip) / rate, 'peak': max(abs(v) for v in clip) / 32768})
preview_dir = ROOT / 'docs/3d_migration/audio_preview'
preview_dir.mkdir(parents=True, exist_ok=True)
(preview_dir / '.gdignore').touch()
save(preview_dir / 'user_steps_preview.wav', preview)
(OUT / 'preparation.json').write_text(json.dumps({
    'source': 'steps-2.mp3', 'source_sha256': hashlib.sha256((OUT / 'source/steps-2.mp3').read_bytes()).hexdigest(),
    'sample_rate': rate, 'global_gain': gain, 'pitch_changed': False,
    'edge_fade_ms': 16, 'highpass_hz': 85, 'lowpass_hz': 2400,
    'lowpass_poles': 2, 'noise_floor': noise_floor, 'target_peak': .22,
    'transient_soft_knee': .14, 'clips': manifest}, indent=2), encoding='utf-8')
print(json.dumps(manifest, indent=2))
