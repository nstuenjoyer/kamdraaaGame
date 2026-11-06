# User-provided footsteps — active 3D bank

5 November 2026. Source: `C:/Users/ilya/Downloads/steps-2.mp3`, supplied by the
user specifically to replace the previous footsteps. No public license is
asserted; the source is not attributed to Kenney or labelled CC0.

`source/steps-2.mp3` is a byte-identical preserved copy, excluded from Godot
import. Original duration: 3.745 seconds. Six natural steps were extracted into
mono 16-bit / 44100 Hz WAV files. Revised after feedback about noise/harshness:
85 Hz high-pass, two-pole 2400 Hz low-pass, gentle envelope-based background
attenuation, soft-knee transient rounding, one common gain and DC correction.
Target peak reduced from 0.5 to 0.22, edge fades extended to 16 ms; runtime volume
reduced by another 3 dB. No pitch changes or synthesis. Source
hash, offsets, lengths and gain are in `preparation.json`.

Reproduce: run `tools/art/decode_user_steps.gd` in Godot (writes the decoded WAV
to `.godot`), then `python tools/art/prepare_user_steps.py`.

Both surface categories currently use this same source bank. With locomotion_v1,
two support markers per animation cycle trigger the recordings. Cadence follows
actual travel and the selected gait, without random pitch shifts. Previous
Kenney files are retained as unused history.
Preview: `docs/3d_migration/audio_preview/user_steps_preview.wav`.

Latest playback update: own footsteps use a non-spatial AudioStreamPlayer,
centred equally in left/right channels. Walking -18 dB, running -15 dB,
sneaking -27 dB. Ambient sources remain spatial. The preview includes the
current -18 dB walking gain instead of playing the raw bank at full volume.
