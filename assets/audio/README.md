# Recorded heartbeat and window rain

Added 1 November 2026. Both recordings are available under CC0.

- **kathol — real heartbeat.wav**: https://freesound.org/people/kathol/sounds/43621/ . The author describes a real heartbeat recorded through a stethoscope after exercise. The downloaded MP3 preview is preserved in `docs/review/audio_sources/heartbeat_recording.mp3`. Runtime `heartbeat_s1.wav` and `heartbeat_s2.wav` are two extracted natural sounds, band-limited to 42–240 Hz with soft sample edges. Pitch is unchanged during playback; BPM changes the interval, not the recording's pitch.
- **alxl — Rain on Window Loop**: https://opengameart.org/content/rain-on-window-loop . The source page explicitly offers CC0. Original WAV: `docs/review/audio_sources/rain_window_original.wav`. Runtime `menu_rain.wav` has filtering, a crossfade seam and a short smooth correction matching stereo endpoints, without a silent gap.

Runtime files: 22050 Hz, signed 16-bit PCM; heart sounds mono, rain stereo. WAV import compression must remain disabled. Sources and processing files stay in the project and are excluded from the PCK.

Reproducible processing: `docs/review/prepare_recorded_audio.gd` decodes the heartbeat into `.godot/heartbeat_decoded.wav`; `tools/art/prepare_recorded_audio.py` prepares the three runtime WAVs. The tool needs numpy, wave and Python. No synthetic heartbeat tone is mixed into the new pulse.
