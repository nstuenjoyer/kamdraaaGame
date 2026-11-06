"""Independent upright-walk regression on saved source, GLB and prior source.

Measures geometry of the thigh/shin chains, not animation-generator parameters.
No model is saved or modified. Run in factory-startup background Blender after
the final candidate has been exported.
"""
import bpy
import math
import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2'
SOURCE = OUT/'source/dasha_locomotion.blend'
EXPORT = OUT/'dasha_locomotion.glb'
BASELINE = OUT/'source/dasha_walk_previous.blend'


def sample_loaded(stances):
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    if rig.animation_data:
        for track in rig.animation_data.nla_tracks:
            track.mute = True
    rig.animation_data_create()
    rest_z = rig.data.bones['pelvis'].head_local.z
    result = {}
    for name, stance in stances.items():
        action = next(a for a in bpy.data.actions if a.name == name or a.name.endswith('_'+name))
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        first, last = action.frame_range

        def sample(phase, side):
            frame = first+(last-first)*(phase % 1)
            bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
            bpy.context.view_layer.update()
            thigh = rig.pose.bones['thigh.'+side]
            shin = rig.pose.bones['shin.'+side]
            foot = rig.pose.bones['foot.'+side]
            upper = (shin.head-thigh.head).normalized()
            lower = (foot.head-shin.head).normalized()
            return {
                'phase':phase,
                'knee_flexion_degrees':math.degrees(math.acos(max(-1,min(1,upper.dot(lower))))),
                'shin_pitch_degrees':math.degrees(math.atan2(-lower.y,-lower.z)),
                'pelvis_lowering_m':rest_z-rig.pose.bones['pelvis'].head.z,
            }

        sides = {}
        for side, shift in [('L',0), ('R',.5)]:
            # Store phase relative to this leg, so left and right are comparable.
            samples = []
            for index in range(121):
                phase = index/120
                row = sample(phase-shift,side)
                row['phase'] = phase
                samples.append(row)
            support = [r for r in samples if r['phase']<stance]
            passing = [r for r in samples if .14<r['phase']<.45]
            swing = [r for r in samples if stance<r['phase']<1]
            loading = [r for r in samples if .025<=r['phase']<=.175]
            knee = lambda r:r['knee_flexion_degrees']
            sides[side] = {
                'support_knee_mean_degrees':sum(knee(r) for r in support)/len(support),
                'support_knee_min_degrees':min(knee(r) for r in support),
                'support_knee_max_degrees':max(knee(r) for r in support),
                'passing_knee_mean_degrees':sum(knee(r) for r in passing)/len(passing),
                'swing_knee_max_degrees':max(knee(r) for r in swing),
                'loading_peak_knee_degrees':max(knee(r) for r in loading),
                'contact_knee_degrees':knee(sample(-shift,side)),
                'after_loading_knee_degrees':knee(sample(.20-shift,side)),
                'pelvis_lowering_min_m':min(r['pelvis_lowering_m'] for r in samples),
                'pelvis_lowering_max_m':max(r['pelvis_lowering_m'] for r in samples),
                'pelvis_lowering_mean_m':sum(r['pelvis_lowering_m'] for r in samples)/len(samples),
                'cycle_samples':samples,
            }
        result[name] = sides
    return result


assert BASELINE.is_file(), BASELINE
bpy.ops.wm.open_mainfile(filepath=str(BASELINE),load_ui=False)
before = sample_loaded({'walk':.62,'sneak':.72})
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False)
source = sample_loaded({'walk':.60,'sneak':.72})
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(EXPORT))
export = sample_loaded({'walk':.60,'sneak':.72})

max_export_difference = 0
for side in ['L','R']:
    current = source['walk'][side]
    assert current['support_knee_mean_degrees']<25, (side,'walk remains crouched',current)
    assert current['passing_knee_mean_degrees']<18, (side,'support leg does not extend',current)
    assert current['swing_knee_max_degrees']<65, (side,'walk swing tucks the calf too far',current)
    assert current['loading_peak_knee_degrees']>max(current['contact_knee_degrees'],current['after_loading_knee_degrees'])+1, (side,'missing brief loading response',current)
    assert current['support_knee_mean_degrees']<before['walk'][side]['support_knee_mean_degrees']-10, (side,'no meaningful improvement vs prior source')
    assert source['sneak'][side]['support_knee_mean_degrees']>current['support_knee_mean_degrees']+30, (side,'walk and sneak remain too similar')
    assert source['sneak'][side]['pelvis_lowering_mean_m']>current['pelvis_lowering_mean_m']+.08, (side,'walk pelvis remains at sneak height')
    difference = max(abs(a['knee_flexion_degrees']-b['knee_flexion_degrees']) for a,b in zip(current['cycle_samples'],export['walk'][side]['cycle_samples']))
    max_export_difference = max(max_export_difference,difference)
    assert difference<2, (side,'source/export knee mismatch',difference)

report = {
    'method':'independent sampled thigh/shin/foot joint positions; 121 phases per leg; '
             'source baseline comparison, upright support, finite swing, loading response and sneak separation',
    'baseline_blend_sha256':hashlib.sha256(BASELINE.read_bytes()).hexdigest(),
    'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'export_glb_sha256':hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
    'max_source_export_knee_difference_degrees':max_export_difference,
    'before':before,'source':source,'export':export,
}
(OUT/'walk_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WALK_VALIDATED',json.dumps({name:{side:{k:v for k,v in metrics.items() if k!='cycle_samples'} for side,metrics in sides.items()} for name,sides in source.items()}),flush=True)
