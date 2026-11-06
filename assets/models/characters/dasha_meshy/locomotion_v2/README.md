# Dasha — corrected locomotion

7 November run follow-up: run had the same persistent crouch at a greater depth.
Only its pelvis/lift curve was revised: support-knee mean70.2°→35.2°, swing
133.3°→90.6°, mean pelvis lowering16.3cm→7.6cm. Landing absorption, subsequent
extension, ankle flexion, stride2.2m and runtime3.6m/s are retained. Accepted walk
is bit-for-bit identical in all31 pose matrices at121 sampled phases.
`source/dasha_run_previous.blend` preserves the before state;
`tools/art/check_dasha_run.py` produces `run_validation.json` with both hashes
and the walk-invariance check. Run profile: `previews/run_side_full_loop.png`.

7 November upright-walk correction: the previous walk kept its support knee
bent28–56° and resembled sneaking. Walk now extends its support leg, briefly
absorbs the heel strike, and transfers the other foot with less lift/folding.
Its shorter stride is matched to runtime1.4m/s. Sneak retains its separate low
posture. `walk_validation.json` measures actual thigh/shin vectors in the source
and GLB against the preserved prior source, instead of only checking clip names.
Support-knee mean41.1°→20.5°, passing37.4°→13.2°, brief heel-loading flexion16.4°
followed by8.9°. The prior source is `source/dasha_walk_previous.blend`.
Source keys and this GLB's Godot import now use120FPS: default30FPS import had
discarded most intermediate poses. Full-profile review: `previews/walk_side_full_loop.png`.

7 November ankle follow-up: swing now has explicit toe-down follow-through,
then dorsiflexion for clearance and heel-first landing, rather than one monotonic
toe-off → landing interpolation through a nearly level passing boot. Walk pitches
approximately30° down early /9° up late, run42° down /12° up. Sole compensation,
weights, head and 31-bone skeleton are retained. `ankle_validation.json` compares
both feet in the saved source and GLB; `tools/art/check_dasha_ankle.py` reproduces
it. Godot also checks the imported global foot orientation, rather than only
the local rotation compensating the shin. Close side preview:
`previews/ankle_walk_side_loop.png` (48 frames).

6 November 2026. Runtime uses this export. `locomotion_v1` is retained as the
previous pass; `rig_v1` and the protected Meshy source remain unchanged.

- `source/dasha_locomotion.blend`: editable 60 FPS actions and skin.
- `dasha_locomotion.glb`: six in-place loops on the same 31-bone skeleton.
- `animation_report.json`: geometry, weights, source invariants and stride lengths.
- `validation.json`: clean GLB import, material/skin, motion, seams and rigid face/bag.
- `contact_validation.json`: independent measurements of saved source, with SHA256.

The Action Editor contains idle/walk/run/sneak/stairs_up/stairs_down. Select
`Dasha_Rig_v1`, choose an action and set timeline end to 481/121/97/169/145/145
respectively. Source scene FPS is 120; clip lengths are 4/1/.8/1.4/1.2/1.2 s.

Corrections:

- Exact stance-distance agreement replaces 25–27% sliding in v1. Constant support
  velocity joins a Hermite swing trajectory with continuous horizontal velocity.
- Heel → flat sole → toe rotation compensates the bottom of the actual boot,
  including its separate sole and lower vamp. Reachable planted targets guide
  pelvis height; running absorbs weight during support and rises during flight.
- Arm counter-swing follows foot excursion, with restrained bag-arm movement.
- Coat/trouser weights are classified by mesh connectivity, rather than an XY
  cut that assigned trousers to cloth and coat to shin bones. Boot shafts blend
  into shins while the sole remains rigid.
- Two planar support cuts on 96 long trouser edges improve knee folds without
  smoothing the silhouette. 25,870 triangles / 12,901 positional vertices; all
  10,000 protected head vertices and 19,779 protected polygons/UVs are unchanged.
- Cloth base movement follows the thigh. Offline clearance fitting shifts front
  and back panels around the leg. A cyclic upper-envelope filter smooths the
  correction while retaining required clearance; modest side-seam spread avoids
  lifting the front panels horizontally. This is baked animation, not runtime
  cloth simulation or runtime IK.
- Runtime movement is calibrated to the gait: walk/run/sneak 1.4/3.6/.62 m/s;
  slope limits 1.0/1.5/.55. Slope enemy speeds .9 search /1.2 chase retain a running
  escape margin. Camera directions, collision, story and save format are retained.
- Smooth starts/stops, deceleration in the current gait, displacement-based
  facing and 120 ms slope hysteresis. Existing quiet centred Foley triggers at
  support markers, not a separate mismatched stride timer.

Reproduce: background factory-startup Blender with the `rig_v1` source and
`tools/art/animate_dasha.py`. `-- --no-previews` skips rendering. Helpers are
`refine_dasha_skin.py` and `dasha_cloth_clearance.py`. Verify exported GLB with
`check_dasha_animation.py` and saved source with `check_dasha_contacts.py`.
Godot: `tools/run_3d_checks.ps1 -AnimationOnly`, `-Visual`, `-Route`.

Latest walk/ankle verification: Godot45/45 plus independent source/GLB/contact
checks. Earlier broader prototype checks: visual/audio/UI76/76,
route/encounter97/97.
Saved-source independent check: all121 sampled phases per moving clip have0
strict edge/triangle crossings in the tested lower-coat/leg region. Flat support
drift below2mm; worst inter-key sole penetration is1.2mm during running roll.
This measures baked source; GLB material/skin/seam/head validation is separate.

Motion review: `tools/art/render_dasha_review.py -- --clip walk --view side`
renders translated character motion from a fixed camera. The separate Godot
fixture `AI/review/capture_dasha_motion.gd` records real Input/physics/Forward+
frames; these are distinguished from Blender model previews in their manifests.
The staircase collision is continuous: stair clips follow its slope, rather than
planting on individually raycast decorative treads. Interaction and encounter
gestures remain outside these six locomotion loops.
