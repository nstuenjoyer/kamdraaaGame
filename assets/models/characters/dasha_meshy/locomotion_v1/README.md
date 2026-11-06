# Dasha — gameplay locomotion, first pass

Superseded by `../locomotion_v2/` after gait, cloth, boot and knee corrections.
Retained as the previous pass; the game loads v2.

6 November 2026. Authored from `rig_v1/source/dasha_rig_v1.blend`.
The protected face, geometry, UVs, three textures and 31-bone skeleton are retained.

- `source/dasha_locomotion.blend`: editable actions and original weighted mesh.
- `dasha_locomotion.glb`: the model now loaded by the 3D prototype.
- `previews/`: actual Blender poses, frame sequences, lossless animated PNGs
  (`*_loop.png`) and looping GIFs.
- `animation_report.json`, `validation.json`: generation and clean GLB checks.

| Action | Duration | Behaviour |
|---|---:|---|
| idle | 4 s | breathing and subtle head/upper-body motion |
| walk | 1 s | alternating support/swing, knee flexion, arm/coat motion |
| run | 0.8 s | stronger lean, lift and arm motion |
| sneak | 1.4 s | lowered pelvis, short quiet steps |
| stairs_up | 1.2 s | higher swing clearance, forward lean, ramp-oriented boots |
| stairs_down | 1.2 s | controlled descent and opposite boot slope |

In Blender select `Dasha_Rig_v1`, switch the Dope Sheet to Action Editor and
choose one of these actions. Their timelines start at frame 1; end frames are
121/31/25/43/37/37 respectively (30 FPS). Press Space to preview. NLA tracks
are retained muted as an action catalogue; the active action is `idle`.

The animation is in place. CharacterBody3D remains responsible for position,
collision and yaw. `scripts/chapter_1_3d/dasha_animation.gd` blends actions over
0.18 s, retains left/right phase across modes and drives cadence from actual
travel. Two support markers per cycle trigger the existing quiet centred Foley.
Zero travel, including pushing a wall, returns to idle without steps.
Physical ramp ascent/descent selects the respective clip; loading another floor
does not. Gameplay movement speeds, camera controls and saves are unchanged.

Leg poses are authored with a two-bone solve and baked to FK keys at 30 FPS.
There is no runtime IK. Ramps have continuous collisions: these clips follow an
approximate ramp slope, not individually detected stair treads. Foot sliding,
coat/leg intersections and joint weights still need artistic polish. These are
first gameplay cycles, not final animation acceptance. Interaction gestures,
hand/flashlight attachment, hiding and encounter choreography remain separate
work; the provisional enemy is unchanged.

Rebuild in isolated background Blender with `tools/art/animate_dasha.py`, then
`tools/art/pack_dasha_animation.py` for lossless animated PNGs or
`tools/art/preview_dasha_animation.ps1` for GIFs. Verify via
`tools/art/check_dasha_animation.py` and `tools/run_3d_checks.ps1 -AnimationOnly`
(`AI/review/check_dasha_animation.gd`).
The latter tests actual input, physical ramp movement and pushing a real wall.
