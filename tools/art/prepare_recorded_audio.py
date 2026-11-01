"""Prepare CC0 field recordings. Decode MP3 using review/prepare_recorded_audio.gd first."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)

def read(path):
    with wave.open(str(path), "rb") as source:
        rate = source.getframerate()
        data = np.frombuffer(source.readframes(source.getnframes()), "<i2")
        return data.astype(np.float64).reshape(-1, source.getnchannels()) / 32768, rate

def filter_audio(data, rate, highpass, lowpass):
    frequency = np.fft.rfftfreq(len(data), 1 / rate)
    gain = (1 / (1 + (highpass / np.maximum(frequency, .01)) ** 6) /
            (1 + (frequency / lowpass) ** 8)) ** .5
    return np.fft.irfft(np.fft.rfft(data, axis=0) * gain[:, None], n=len(data), axis=0)

def save(name, data, rate, peak, match_loop=False):
    target_rate = 22050
    timeline = np.arange(round(len(data) * target_rate / rate)) * rate / target_rate
    data = np.column_stack([np.interp(timeline, np.arange(len(data)), channel) for channel in data.T])
    if match_loop:
        # Keep the noise continuous rather than silencing the seam. A short,
        # smooth DC correction brings both stereo endpoints to their midpoint.
        span = round(target_rate * .010)
        midpoint = (data[0] + data[-1]) * .5
        weight = (1 + np.cos(np.linspace(0, np.pi, span)))[:, None] * .5
        data[:span] += (midpoint - data[0]) * weight
        data[-span:] += (midpoint - data[-1]) * weight[::-1]
    data *= peak / max(.001, float(np.abs(data).max()))
    with wave.open(str(OUT / name), "wb") as result:
        result.setnchannels(data.shape[1])
        result.setsampwidth(2)
        result.setframerate(target_rate)
        result.writeframes(np.rint(data * 32767).astype("<i2").tobytes())

heart, rate = read(ROOT / ".godot/heartbeat_decoded.wav")
heart = filter_audio(heart, rate, 42, 240)
for name, start, end, peak in [("heartbeat_s1.wav", .026, .140, .55), ("heartbeat_s2.wav", .146, .285, .39)]:
    sample = heart[round(start * rate):round(end * rate)].copy()
    attack, release = round(rate * .009), round(rate * .020)
    sample[:attack] *= np.linspace(0, 1, attack)[:, None] ** 2
    sample[-release:] *= np.linspace(1, 0, release)[:, None] ** 2
    save(name, sample, rate, peak)

rain, rate = read(ROOT / "docs/review/audio_sources/rain_window_original.wav")
rain = filter_audio(rain, rate, 30, 8000)
overlap = round(rate * .30)
fade = np.linspace(0, 1, overlap)[:, None]
seam = rain[-overlap:] * (1 - fade) + rain[:overlap] * fade
rain = np.concatenate([seam, rain[overlap:-overlap]])
save("menu_rain.wav", rain, rate, .60, match_loop=True)
print("Prepared recorded S1/S2 and stereo rain loop")
