"""Check the saved run correction while preserving the accepted walk.

Run in factory-startup background Blender. Reads baseline/source/export, never
saves or regenerates a model. Joint-vector measurements are independent of the
animation generator's parameter values. World-matrix preservation is tested on
all original skeleton controls throughout the accepted walk, not just its name.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2'
BASELINE = OUT/'source/dasha_run_previous.blend'
SOURCE = OUT/'source/dasha_locomotion.blend'
EXPORT = OUT/'dasha_locomotion.glb'
SAMPLES = 121


def loaded_rig():
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    return rig


def set_action(rig, name):
    action = next(a for a in bpy.data.actions if a.name == name or a.name.endswith('_'+name))
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    return action


def set_phase(action, phase):
    start, end = action.frame_range
    frame = start+(end-start)*(phase % 1)
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()


def walk_matrices(rig):
    action = set_action(rig, 'walk')
    result = []
    for index in range(SAMPLES):
        set_phase(action,index/(SAMPLES-1))
        result.append({bone.name:[float(value) for row in bone.matrix for value in row]
                       for bone in rig.pose.bones})
    return result


def run_metrics(rig):
    action = set_action(rig,'run')
    rest_pelvis = rig.data.bones['pelvis'].head_local.z
    rest_foot = {side:rig.data.bones['foot.'+side].matrix_local.copy() for side in ['L','R']}
    sides = {}
    for side,shift in [('L',0),('R',.5)]:
        rows = []
        for index in range(SAMPLES):
            phase = index/(SAMPLES-1)
            set_phase(action,phase-shift)
            thigh = rig.pose.bones['thigh.'+side]
            shin = rig.pose.bones['shin.'+side]
            foot = rig.pose.bones['foot.'+side]
            upper = (shin.head-thigh.head).normalized()
            lower = (foot.head-shin.head).normalized()
            sole = (foot.matrix @ rest_foot[side].inverted()).to_3x3() @ Vector((0,-1,0))
            rows.append({'phase':phase,
                'knee_flexion_degrees':math.degrees(math.acos(max(-1,min(1,upper.dot(lower))))),
                'shin_pitch_degrees':math.degrees(math.atan2(-lower.y,-lower.z)),
                'sole_pitch_degrees':math.degrees(math.atan2(sole.z,-sole.y)),
                'pelvis_lowering_m':rest_pelvis-rig.pose.bones['pelvis'].head.z})
        support = [r for r in rows if r['phase']<.4]
        swing = [r for r in rows if .4<r['phase']<1]
        loading = [r for r in rows if .10<=r['phase']<=.25]
        landing = min(rows,key=lambda r:abs(r['phase']))
        late = min(rows,key=lambda r:abs(r['phase']-.35))
        early_swing = [r for r in rows if .4<r['phase']<.6]
        late_swing = [r for r in rows if .8<r['phase']<1]
        k = lambda r:r['knee_flexion_degrees']
        sides[side] = {
            'support_knee_mean_degrees':sum(k(r) for r in support)/len(support),
            'support_knee_min_degrees':min(k(r) for r in support),
            'support_knee_max_degrees':max(k(r) for r in support),
            'swing_knee_max_degrees':max(k(r) for r in swing),
            'loading_peak_knee_degrees':max(k(r) for r in loading),
            'landing_knee_degrees':k(landing),
            'late_support_knee_degrees':k(late),
            'early_swing_min_shin_pitch_degrees':min(r['shin_pitch_degrees'] for r in early_swing),
            'late_swing_max_shin_pitch_degrees':max(r['shin_pitch_degrees'] for r in late_swing),
            'pelvis_lowering_mean_m':sum(r['pelvis_lowering_m'] for r in rows)/len(rows),
            'pelvis_lowering_min_m':min(r['pelvis_lowering_m'] for r in rows),
            'pelvis_lowering_max_m':max(r['pelvis_lowering_m'] for r in rows),
            'cycle_samples':rows}
    return sides


assert BASELINE.is_file(),BASELINE
bpy.ops.wm.open_mainfile(filepath=str(BASELINE),load_ui=False)
rig = loaded_rig()
before = run_metrics(rig)
walk_before = walk_matrices(rig)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False)
rig = loaded_rig()
source = run_metrics(rig)
walk_after = walk_matrices(rig)
walk_error = 0
for old,new in zip(walk_before,walk_after):
    assert old.keys()==new.keys(),'Accepted walk controls changed'
    walk_error = max(walk_error,max(abs(a-b) for name in old for a,b in zip(old[name],new[name])))
assert walk_error<1e-5,('Accepted walk poses changed',walk_error)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(EXPORT))
export = run_metrics(loaded_rig())
export_error = 0
for side in ['L','R']:
    current = source[side]
    assert current['support_knee_mean_degrees']<50,(side,'Run remains crouched',current)
    assert current['support_knee_mean_degrees']<before[side]['support_knee_mean_degrees']-20,(side,'No material support improvement')
    assert current['swing_knee_max_degrees']<110,(side,'Run folds calf too far under coat',current)
    assert current['swing_knee_max_degrees']<before[side]['swing_knee_max_degrees']-20,(side,'No material swing improvement')
    assert current['pelvis_lowering_mean_m']<.11,(side,'Run pelvis remains deeply lowered')
    assert current['loading_peak_knee_degrees']>current['landing_knee_degrees']+10,(side,'Missing run landing absorption')
    assert current['late_support_knee_degrees']<current['loading_peak_knee_degrees']-1,(side,'Run never extends after absorption')
    assert current['late_swing_max_shin_pitch_degrees']>current['early_swing_min_shin_pitch_degrees']+40,(side,'Calf does not unfold for landing')
    difference = max(abs(a['knee_flexion_degrees']-b['knee_flexion_degrees']) for a,b in
                     zip(current['cycle_samples'],export[side]['cycle_samples']))
    export_error = max(export_error,difference)
    assert difference<2,(side,'Run source/export knee mismatch',difference)

report = {'method':'independent121-phase thigh/shin vectors; run absorption/extension, '
                   'calf recovery and all-control accepted-walk matrix preservation',
    'baseline_blend_sha256':hashlib.sha256(BASELINE.read_bytes()).hexdigest(),
    'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'export_glb_sha256':hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
    'walk_max_pose_matrix_difference':walk_error,
    'max_source_export_knee_difference_degrees':export_error,
    'before':before,'source':source,'export':export}
(OUT/'run_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('RUN_VALIDATED',json.dumps({'walk_max_pose_matrix_difference':walk_error,
    'max_source_export_knee_difference_degrees':export_error,
    'run':{side:{k:v for k,v in metrics.items() if k!='cycle_samples'} for side,metrics in source.items()}}),flush=True)
