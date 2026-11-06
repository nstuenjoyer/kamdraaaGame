"""Clean GLB roundtrip, skin normalization and rigid-head deformation check."""
import bpy
import json
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/characters/dasha_meshy/rig_v1'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'dasha_rig_v1.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mesh.data.calc_loop_triangles()
assert len(mesh.data.loop_triangles)==25434
assert len(rig.data.bones)>=30
assert any(m.type=='ARMATURE' and m.object==rig for m in mesh.modifiers)
assert all(0<len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in mesh.data.vertices)
bind=[mesh.matrix_world @ v.co for v in mesh.data.vertices]
tree=KDTree(len(bind))
for i,p in enumerate(bind):tree.insert(p,i)
tree.balance()
bpy.ops.import_scene.gltf(filepath=str(OUT.parent/'psx_face_preserved/dasha_psx_working.glb'))
source=next(o for o in bpy.context.selected_objects if o.type=='MESH')
errors=[tree.find(source.matrix_world @ v.co)[2] for v in source.data.vertices]
assert max(errors)<1e-5,max(errors)
source.hide_render=True
rig.animation_data_clear()
for bone in rig.pose.bones:bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0)
rig.pose.bones['head'].rotation_euler.z=.18
bpy.context.view_layer.update()
evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
deformed=evaluated.to_mesh()
lo=min(v.z for v in bind);height=max(v.z for v in bind)-lo
bone=rig.pose.bones['head']
transform=rig.matrix_world @ bone.matrix @ rig.data.bones['head'].matrix_local.inverted() @ rig.matrix_world.inverted()
head_errors=[]
for i,point in enumerate(bind):
    if (point.z-lo)/height>.815:
        head_errors.append(((evaluated.matrix_world @ deformed.vertices[i].co)-(transform @ point)).length)
assert head_errors and max(head_errors)<1e-5,max(head_errors,default=-1)
evaluated.to_mesh_clear()
report={'roundtrip':'pass','triangles':25434,'bones':len(rig.data.bones),
        'bind_source_max_error':max(errors),'rotated_head_max_rigid_error':max(head_errors),
        'head_checks':len(head_errors),'weights_normalized':True,'max_influences':4}
(OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('RIG_VALIDATED',json.dumps(report),flush=True)
