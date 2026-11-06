# Dasha — first FK rig

5 November 2026. Source: the protected-face Meshy working model.

- `source/dasha_rig_v1.blend`: editable rig and skin weights. Armature is shown
  in front in the viewport. Input source files were not overwritten.
- `dasha_rig_v1.glb`: game export, 31 bones, skin, original three textures and
  25434 triangles. Retained as the source baseline; the game now uses the
  sibling `locomotion_v1` export with first gameplay cycles.
- `walk_test`: a small FK deformation exercise, not a finished locomotion clip.
- `previews/bind.png`, `previews/walk_test.png`: actual Blender renders.
- `rig_report.json`, `validation.json`: generation and clean roundtrip checks.

Skeleton: root/pelvis/spine/chest/neck/head, bilateral clavicle/arm/forearm/hand,
thigh/shin/foot/toe, front/back coat panels with tips, bag parented to right hand.
The accessory was isolated by mesh connectivity below the wrist (362 vertices),
not an X-plane cut across the bag. At most four normalized influences per vertex.
Head vertices above the protected boundary are rigidly assigned to the head bone.

No vertex positions, UVs or source materials were changed. Bind-pose displacement
is below 0.000002 Blender units after GLB roundtrip. A head-turn test verifies
rigid facial movement rather than relying only on vertex counts.

This is a first deformation pass. It does not replace animation retopology:
joint loops, coat/leg intersections, hand grips, foot contacts and IK need
further work. `walk_test` remains available for inspection in Blender/Godot,
not presented as a finished walk. The sibling `locomotion_v1` contains the
first authored gameplay cycles and their separate validation/limits.

Rebuild: `tools/art/rig_dasha_v1.py` in an isolated background Blender against
`psx_face_preserved/source/dasha_psx_working.blend`. Validation:
`tools/art/check_dasha_rig.py` in factory-startup Blender and
`AI/review/check_dasha_rig.gd` in Godot after importing the GLB.
