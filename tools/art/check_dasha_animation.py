"""Validate exported clips/skin, loop seams and rigid face/accessory motion."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'dasha_locomotion.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
obj.data.calc_loop_triangles()
assert len(obj.data.loop_triangles) == 25870
assert len(rig.data.bones) == 31
assert all(0 < len(v.groups) <= 4 and abs(sum(g.weight for g in v.groups)-1)<1e-5
           for v in obj.data.vertices)
assert len(obj.data.materials) == 1
assert len([n for n in obj.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE']) == 3
rig.animation_data_clear()
rig.animation_data_create()
bind = [obj.matrix_world @ v.co for v in obj.data.vertices]
lo = min(p.z for p in bind)
height = max(p.z for p in bind)-lo
groups = {g.index:g.name for g in obj.vertex_groups}
protected = [i for i,p in enumerate(bind) if (p.z-lo)/height>.815]
bags = [v.index for v in obj.data.vertices if len(v.groups) == 1
        and groups[v.groups[0].group] == 'bag']
assert len(bags) > 300
actions = {name: next(a for a in bpy.data.actions if name == a.name or a.name.endswith('_'+name))
           for name in ['idle','walk','run','sneak','stairs_up','stairs_down']}
report = {'triangles':len(obj.data.loop_triangles), 'bones':31, 'protected_head_vertices':len(protected),
          'rigid_bag_vertices':len(bags), 'clips':{}}
for name, action in actions.items():
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    start, end = action.frame_range
    def frame_set(frame):
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    frame_set(start)
    first = {p.name:p.matrix.copy() for p in rig.pose.bones}
    frame_set(end)
    last = {p.name:p.matrix.copy() for p in rig.pose.bones}
    seam = max(max(abs(first[n][i][j]-last[n][i][j]) for i in range(4) for j in range(4)) for n in first)
    assert seam < 1e-4, (name, seam)
    frame_set(start+(end-start)*.25)
    moving_bone = 'spine' if name == 'idle' else 'thigh.L'
    motion = max(abs(first[moving_bone][i][j]-rig.pose.bones[moving_bone].matrix[i][j])
                 for i in range(4) for j in range(4))
    assert motion > .001, (name, 'animation did not evaluate', motion)
    max_head = max_bag = 0
    for sample in range(13):
        frame = start+(end-start)*sample/12
        frame_set(frame)
        bpy.context.view_layer.update()
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        posed = evaluated.to_mesh()
        for bone_name, ids in [('head',protected), ('bag',bags)]:
            transform = (rig.matrix_world @ rig.pose.bones[bone_name].matrix
                         @ rig.data.bones[bone_name].matrix_local.inverted() @ rig.matrix_world.inverted())
            error = max(((evaluated.matrix_world @ posed.vertices[i].co)-(transform @ bind[i])).length for i in ids)
            assert error < 1e-5, (name, bone_name, frame, error)
            if bone_name == 'head': max_head = max(max_head,error)
            else: max_bag = max(max_bag,error)
        evaluated.to_mesh_clear()
        assert rig.pose.bones['root'].location.length < 1e-5
    report['clips'][name] = {'loop_max_error':seam, 'pose_motion':motion, 'head_rigid_max_error':max_head,
                             'bag_rigid_max_error':max_bag}
(OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ANIMATION_VALIDATED',json.dumps(report),flush=True)
