"""First FK deformation rig, preserving Meshy geometry/materials at bind pose.

Run against psx_face_preserved/source/dasha_psx_working.blend in isolated Blender.
Weights are a reviewed starting point, not animation retopology.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/characters/dasha_meshy/rig_v1'
for folder in (OUT, OUT/'source', OUT/'previews'):
    folder.mkdir(parents=True, exist_ok=True)
for folder in (OUT/'source', OUT/'previews'):
    (folder/'.gdignore').touch()
scene = bpy.context.scene
obj = bpy.data.objects.get('Dasha_PSX_Working')
assert obj is not None
obj.hide_render = False
obj.hide_set(False)
world = [obj.matrix_world @ v.co for v in obj.data.vertices]
lo = Vector(tuple(min(p[i] for p in world) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in world) for i in range(3)))
h = hi.z-lo.z
cx = (lo.x+hi.x)/2
cy = (lo.y+hi.y)/2


def p(x,y,z): return Vector((cx+x*h, cy+y*h, lo.z+z*h))


bones = {}
def bone(name, head, tail, parent=None): bones[name] = (p(*head),p(*tail),parent)
bone('root',(0,0,0),(0,0,.12))
bone('pelvis',(0,0,.49),(0,0,.57),'root')
bone('spine',(0,0,.57),(0,0,.66),'pelvis')
bone('chest',(0,0,.66),(0,0,.78),'spine')
bone('neck',(0,0,.78),(0,0,.84),'chest')
bone('head',(0,0,.84),(0,0,.99),'neck')
for side, sign in [('L',1),('R',-1)]:
    bone('clavicle.'+side,(0,0,.77),(.081*sign,0,.78),'chest')
    bone('upper_arm.'+side,(.081*sign,0,.78),(.12*sign,0,.65),'clavicle.'+side)
    bone('forearm.'+side,(.12*sign,0,.65),(.155*sign,-.005,.53),'upper_arm.'+side)
    bone('hand.'+side,(.155*sign,-.005,.53),(.16*sign,-.012,.475),'forearm.'+side)
    bone('thigh.'+side,(.065*sign,.005,.49),(.075*sign,.006,.285),'pelvis')
    bone('shin.'+side,(.075*sign,.006,.285),(.075*sign,0,.075),'thigh.'+side)
    bone('foot.'+side,(.075*sign,0,.075),(.075*sign,-.065,.035),'shin.'+side)
    bone('toe.'+side,(.075*sign,-.065,.035),(.075*sign,-.105,.025),'foot.'+side)
    for panel, y in [('front',-.055),('back',.065)]:
        name = f'coat_{panel}.{side}'
        bone(name,(.07*sign,y,.50),(.085*sign,y,.38),'pelvis')
        bone(name+'_tip',(.085*sign,y,.38),(.10*sign,y,.255),name)
bone('bag',(-.16,0,.50),(-.17,0,.30),'hand.R')

arm = bpy.data.armatures.new('Dasha_Rig_v1')
rig = bpy.data.objects.new('Dasha_Rig_v1',arm)
scene.collection.objects.link(rig)
rig.show_in_front = True
arm.display_type = 'OCTAHEDRAL'
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name,(head,tail,parent) in bones.items():
    edit = arm.edit_bones.new(name)
    edit.head, edit.tail = head, tail
    if parent: edit.parent = arm.edit_bones[parent]
    edit.use_deform = name != 'root'
bpy.ops.object.mode_set(mode='OBJECT')
obj.vertex_groups.clear()
groups = {name:obj.vertex_groups.new(name=name) for name in bones if name != 'root'}


def smooth(a,b,x):
    t = max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)


def blend(a,b,t): return {a:1-t,b:t}


def segment_distance(point, name):
    a,b,_ = bones[name]
    offset = b-a
    t = max(0,min(1,(point-a).dot(offset)/offset.length_squared))
    return (point-(a+offset*t)).length/h


# Find disconnected accessory islands, if present, to keep the bag rigid.
parents = list(range(len(world)))
def find(i):
    while parents[i]!=i:
        parents[i]=parents[parents[i]]; i=parents[i]
    return i
for edge in obj.data.edges:
    a,b=edge.vertices; parents[find(a)] = find(b)
islands = {}
for i in range(len(world)): islands.setdefault(find(i),[]).append(i)
bag_ids = set()
for ids in islands.values():
    points=[world[i] for i in ids]
    center=sum(points,Vector())/len(points)
    if len(ids)>8 and (center.x-cx)/h<-.13 and .27<(center.z-lo.z)/h<.52:
        bag_ids.update(ids)
if not bag_ids:
    # The accessory joins the hand in Meshy's mesh. Isolate it by connectivity
    # below the wrist, instead of cutting its inner face with an X threshold.
    allowed={i for i,point in enumerate(world) if (point.x-cx)/h<-.115 and .275<(point.z-lo.z)/h<.54}
    seeds=[i for i in allowed if .32<(world[i].z-lo.z)/h<.38]
    adjacency=[[] for _ in world]
    for edge in obj.data.edges:
        a,b=edge.vertices
        adjacency[a].append(b);adjacency[b].append(a)
    stack=[min(seeds,key=lambda i:world[i].x)] if seeds else []
    while stack:
        i=stack.pop()
        if i in bag_ids or i not in allowed: continue
        bag_ids.add(i)
        stack.extend(adjacency[i])

face_ids = []
for vertex,point in zip(obj.data.vertices,world):
    x,y,z=(point.x-cx)/h,(point.y-cy)/h,(point.z-lo.z)/h
    side='L' if x>=0 else 'R'
    if z>.815:
        weights={'head':1};face_ids.append(vertex.index)
    elif vertex.index in bag_ids:
        weights={'bag':1}
    else:
        if z>.77: weights=blend('chest','neck',smooth(.77,.815,z))
        elif z>.65: weights=blend('spine','chest',smooth(.65,.77,z))
        elif z>.52: weights=blend('pelvis','spine',smooth(.52,.65,z))
        else: weights={'pelvis':1}
        arm_factor=smooth(.085+max(0,.76-z)*.16,.108+max(0,.76-z)*.16,abs(x)) if .46<z<.80 else 0
        if arm_factor>0:
            candidates=[f'upper_arm.{side}',f'forearm.{side}',f'hand.{side}']
            scores={n:math.exp(-segment_distance(point,n)**2/(2*.025**2)) for n in candidates}
            total=sum(scores.values()) or 1
            weights={n:w*(1-arm_factor) for n,w in weights.items()}
            for n,w in scores.items(): weights[n]=weights.get(n,0)+arm_factor*w/total
        elif z<.53:
            # Outer coat surface receives independent cloth panels, not shin weights.
            outer=smooth(.045,.075,abs(y))
            if abs(x)>.095: outer=max(outer,smooth(.095,.135,abs(x)))
            coat_factor=outer*smooth(.24,.29,z)*(1-smooth(.47,.54,z))
            if z<.16: weights={f'foot.{side}':1}
            elif z<.25: weights=blend(f'foot.{side}',f'shin.{side}',smooth(.16,.20,z))
            else: weights=blend(f'shin.{side}',f'thigh.{side}',smooth(.24,.34,z))
            if z>.43:
                t=smooth(.43,.53,z)
                weights={n:w*(1-t) for n,w in weights.items()}
                weights['pelvis']=t
            if coat_factor>0:
                panel=f'coat_{"front" if y<0 else "back"}.{side}'
                cloth=blend(panel+'_tip',panel,smooth(.31,.43,z))
                weights={n:w*(1-coat_factor) for n,w in weights.items()}
                for n,w in cloth.items(): weights[n]=weights.get(n,0)+w*coat_factor
    weights=dict(sorted(weights.items(),key=lambda item:item[1],reverse=True)[:4])
    total=sum(weights.values())
    assert total>0
    for name,weight in weights.items():
        if weight/total>1e-7: groups[name].add([vertex.index],weight/total,'REPLACE')

modifier=obj.modifiers.new('Dasha deformation','ARMATURE')
modifier.object=rig
matrix=obj.matrix_world.copy()
obj.parent=rig
obj.matrix_world=matrix
bpy.context.view_layer.update()

def evaluated_positions():
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    result=[evaluated.matrix_world @ v.co for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return result

rest_error=max((a-b).length for a,b in zip(world,evaluated_positions()))
assert rest_error<1e-5,rest_error
for vertex in obj.data.vertices:
    deform=[g for g in vertex.groups if g.weight>1e-7]
    assert 1<=len(deform)<=4
    assert abs(sum(g.weight for g in deform)-1)<1e-5
report={'bones':len(bones),'vertices':len(world),'rest_pose_max_error':rest_error,
        'rigid_head_vertices':len(face_ids),'bag_island_vertices':len(bag_ids),
        'bag_weighted_vertices':sum(any(g.group==groups['bag'].index and g.weight>.5 for g in v.groups) for v in obj.data.vertices),
        'max_influences':4,'materials_preserved':True,'topology_changed':False,
        'status':'First FK rig; coat and joints need artist deformation review'}

# Small, explicitly labelled deformation exercises; no claim of finished animation.
scene.frame_start=1;scene.frame_end=25;scene.render.fps=30
for name in bones:
    rig.pose.bones[name].rotation_mode='XYZ'
for frame in [1,7,13,19,25]:
    phase=(frame-1)/24*math.tau
    for pose in rig.pose.bones:
        pose.rotation_euler=(0,0,0)
    for side,sign in [('L',1),('R',-1)]:
        swing=math.sin(phase)*sign
        rig.pose.bones['thigh.'+side].rotation_euler.x=math.radians(12)*swing
        rig.pose.bones['shin.'+side].rotation_euler.x=math.radians(-14)*max(0,-swing)
        rig.pose.bones['upper_arm.'+side].rotation_euler.x=math.radians(-7)*swing
        for panel in ['front','back']:
            rig.pose.bones[f'coat_{panel}.{side}'].rotation_euler.x=math.radians(6)*swing
            rig.pose.bones[f'coat_{panel}.{side}_tip'].rotation_euler.x=math.radians(3)*swing
    for pose in rig.pose.bones:
        pose.keyframe_insert('rotation_euler',frame=frame,group=pose.name)
rig.animation_data.action.name='walk_test'
scene.frame_set(1)
obj['rig_status']=report['status']
rig['rig_status']=report['status']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/dasha_rig_v1.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'dasha_rig_v1.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_animations=True,export_force_sampling=True)
camera=scene.camera
center=(lo+hi)/2
camera.data.ortho_scale=h*1.18
camera.location=center+Vector((1.3,-2.8,.72))*h
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
for frame,label in [(1,'bind'),(7,'walk_test')]:
    scene.frame_set(frame)
    scene.render.filepath=str(OUT/'previews'/f'{label}.png')
    bpy.ops.render.render(write_still=True)
scene.frame_set(1)
(OUT/'rig_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('RIG_CREATED',json.dumps(report),flush=True)
