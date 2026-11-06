"""Independent ankle-motion regression check on the saved source and GLB.

Run in factory-startup background Blender. This does not execute the animation
generator, alter weights, or save the loaded model. Positive sole pitch means
toes above the heel; the authored roll convention has the opposite sign.
"""
import bpy
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2'
SOURCE = OUT/'source/dasha_locomotion.blend'
EXPORT = OUT/'dasha_locomotion.glb'
STANCES = {'walk':.60, 'run':.40}


def frame_set(frame):
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()


def inspect_loaded():
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and
                any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers))
    actions = {name:next(a for a in bpy.data.actions if a.name == name or a.name.endswith('_'+name))
               for name in STANCES}
    rig.animation_data_clear()
    rig.animation_data_create()
    rest = {side:rig.data.bones['foot.'+side].matrix_local.copy() for side in ['L','R']}
    report = {}
    for name, stance in STANCES.items():
        action = actions[name]
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        first, last = action.frame_range

        def sample(phase, side):
            frame_set(first+(last-first)*(phase % 1))
            foot = rig.pose.bones['foot.'+side]
            deformation = foot.matrix @ rest[side].inverted()
            direction = deformation.to_3x3() @ Vector((0,-1,0))
            pitch = math.degrees(math.atan2(direction.z,-direction.y))
            # This is a local rig Euler component, not a medical joint angle.
            local_x = math.degrees(foot.matrix_basis.to_euler('XYZ').x)
            assert math.isfinite(pitch) and math.isfinite(local_x)
            return {'phase':phase, 'sole_pitch_degrees':pitch,
                    'local_rig_ankle_x_degrees':local_x}

        sides = {}
        for side, shift in [('L',0),('R',.5)]:
            cycle = [sample(i/120-shift,side) for i in range(121)]
            early = [sample(stance+(1-stance)*u-shift,side)
                     for u in [.05,.10,.15,.20,.25,.30]]
            later = [sample(stance+(1-stance)*u-shift,side)
                     for u in [.55,.60,.65,.70,.75,.80,.85,.90,.95]]
            takeoff = sample(stance-shift,side)
            landing = sample(-shift,side)
            early_plantar = -min(p['sole_pitch_degrees'] for p in early)
            late_dorsal = max(p['sole_pitch_degrees'] for p in later)
            assert early_plantar > (20 if name == 'walk' else 30), (name,side,'no early-swing plantarflexion',early_plantar)
            assert late_dorsal > 3, (name,side,'no late-swing toe clearance',late_dorsal)
            assert -takeoff['sole_pitch_degrees'] > (18 if name == 'walk' else 26), (name,side,'weak toe-off',takeoff)
            expected_landing = 9 if name == 'walk' else 12
            assert abs(landing['sole_pitch_degrees']-expected_landing)<1.5, (name,side,'landing pitch discontinuity',landing)
            sides[side] = {
                'early_swing_plantarflexion_degrees':early_plantar,
                'later_swing_dorsiflexion_degrees':late_dorsal,
                'takeoff_sole_pitch_degrees':takeoff['sole_pitch_degrees'],
                'landing_sole_pitch_degrees':landing['sole_pitch_degrees'],
                'local_rig_ankle_x_range_degrees':[
                    min(p['local_rig_ankle_x_degrees'] for p in cycle),
                    max(p['local_rig_ankle_x_degrees'] for p in cycle)],
                'cycle_samples':cycle,
            }
        report[name] = sides
    report['toe_weighted_vertices'] = {
        side:sum(any(mesh.vertex_groups[g.group].name == 'toe.'+side and g.weight>.001
                     for g in v.groups) for v in mesh.data.vertices)
        for side in ['L','R']}
    return report


bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False)
source_report = inspect_loaded()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(EXPORT))
export_report = inspect_loaded()
max_difference = 0
for name in STANCES:
    for side in ['L','R']:
        samples_source = source_report[name][side]['cycle_samples']
        samples_export = export_report[name][side]['cycle_samples']
        difference = max(abs(a['sole_pitch_degrees']-b['sole_pitch_degrees'])
                         for a,b in zip(samples_source,samples_export))
        max_difference = max(max_difference,difference)
        assert difference < 1.0, (name,side,'source/GLB pitch mismatch',difference)
report = {
    'method':'independent saved-source and exported-GLB sole orientation vs bind; '
             'toe-off, early plantarflexion, late dorsiflexion and landing for both feet',
    'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'export_glb_sha256':hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
    'source_export_max_pitch_difference_degrees':max_difference,
    'source':source_report, 'export':export_report,
}
(OUT/'ankle_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
summary = {name:{side:{k:v for k,v in data.items() if k != 'cycle_samples'}
                for side,data in export_report[name].items()} for name in STANCES}
print('ANKLE_VALIDATED',json.dumps(summary),flush=True)
