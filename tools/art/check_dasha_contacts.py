"""Independent contact/intersection measurements on saved locomotion_v2 source.

Run in background Blender. This script opens the saved blend, never executes
the generator and never rewrites the model. Output is measurement, not an
artistic acceptance claim. Source keys are sampled between baked frames too.
"""
import bpy
import json
import hashlib
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/dasha_locomotion.blend'),load_ui=False)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type=='ARMATURE')
mesh = next(o for o in scene.objects if o.type=='MESH' and o.parent==rig)
manifest = json.loads((OUT/'animation_report.json').read_text(encoding='utf8'))
classification = json.loads((OUT/'skin_classification.json').read_text(encoding='utf8'))
base = [mesh.matrix_world@v.co for v in mesh.data.vertices]
low = min(p.z for p in base)
height = max(p.z for p in base)-low
groups = {g.index:g.name for g in mesh.vertex_groups}
soles = {}
for side in ['L','R']:
    soles[side] = [i for i in classification['soles']+classification['legs'] if
        (base[i].z-low)/height<.085 and
        any(groups[g.group]=='foot.'+side and g.weight>.999 for g in mesh.data.vertices[i].groups)]
    assert len(soles[side])>50
coat_ids, leg_ids = set(classification['coat']),set(classification['legs'])
mesh.data.calc_loop_triangles()
cloth_tris = [tuple(t.vertices) for t in mesh.data.loop_triangles if
    all(i in coat_ids and (base[i].z-low)/height<.43 for i in t.vertices)]
leg_edges = [tuple(e.vertices) for e in mesh.data.edges if
    all(i in leg_ids and .20<(base[i].z-low)/height<.43 for i in e.vertices)]
assert len(cloth_tris)>40 and len(leg_edges)>40
STANCES = {'walk':.60,'run':.40,'sneak':.72,'stairs_up':.64,'stairs_down':.64}
report = {'method':'saved source keys sampled with explicit forward root translation; '
                  'heel/flat/toe rigid sole landmarks; strict leg-edge/cloth-triangle crossings',
          'source_blend_sha256':hashlib.sha256((OUT/'source/dasha_locomotion.blend').read_bytes()).hexdigest(),
          'support_vertices':'all rigid foot vertices below .085H, main boot and detached sole',
          'sample_count_per_cycle':121, 'cloth_triangles_below_043H':len(cloth_tris),
          'leg_edges_020_to_043H':len(leg_edges), 'clips':{}}


def evaluate(action, phase):
    rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    first,last=action.frame_range
    frame=first+(last-first)*(phase % 1)
    scene.frame_set(int(frame),subframe=frame%1)
    bpy.context.view_layer.update()
    evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    geometry=evaluated.to_mesh()
    points=[evaluated.matrix_world@v.co for v in geometry.vertices]
    evaluated.to_mesh_clear()
    return points


def crossings(points, breakdown=False):
    tree=BVHTree.FromPolygons(points,cloth_tris,all_triangles=True,epsilon=0)
    count=0
    panels={}
    for a,b in leg_edges:
        offset=points[b]-points[a]
        length=offset.length
        if length<1e-5:continue
        direction=offset/length
        location,normal,index,distance=tree.ray_cast(points[a]+direction*1e-5,direction,length-2e-5)
        if location is not None and distance>1e-5 and abs(normal.dot(direction))>.05:
            count+=1
            center=sum((base[i] for i in cloth_tris[index]),Vector())/3
            panel=('L' if center.x>0 else 'R')+('_front' if center.y<0 else '_back')
            panels[panel]=panels.get(panel,0)+1
    return {'count':count,'panels':panels} if breakdown else count


report['bind_edge_crossings']=crossings(base)
print('BIND_CROSSINGS',report['bind_edge_crossings'],flush=True)

for name,stance in STANCES.items():
    action=next(a for a in bpy.data.actions if a.name==name)
    distance=manifest['clips'][name]['cycle_distance']
    slope=.45 if name=='stairs_up' else (-.45 if name=='stairs_down' else 0)
    plane_y=rig.data.bones['foot.L'].head_local.y
    normalization=math.sqrt(1+slope*slope)
    def clearance(p):
        return (p.z-low+slope*(p.y-plane_y))/normalization
    def world_points(phase):
        points=evaluate(action,phase)
        offset=Vector((0,-distance*phase,slope*distance*phase))
        return [p+offset for p in points]
    item={'support_segments':{}, 'min_sole_clearance_m':1e6,
          'max_support_clearance_m':0,'crossings_by_frame':[]}
    for side,shift in [('L',0),('R',.5)]:
        segments=[('heel',0,.14),('flat',.14,stance-.16),('toe',stance-.16,stance)]
        for label,start,end in segments:
            midpoint=world_points((start+end)/2-shift)
            landmark=min(soles[side],key=lambda i:clearance(midpoint[i]))
            first=None
            drift=0
            vertical=0
            for sample in range(25):
                phase=start+(end-start)*sample/24-shift
                point=world_points(phase)[landmark]
                if first is None:first=point
                drift=max(drift,Vector((point.x-first.x,point.y-first.y,0)).length)
                vertical=max(vertical,abs(clearance(point)))
            item['support_segments'][side+'_'+label]={
                'landmark_vertex':landmark,'world_horizontal_drift_m':drift,
                'max_absolute_plane_clearance_m':vertical}
    max_crossings=0
    for sample in range(121):
        phase=sample/120
        points=world_points(phase)
        for side,shift in [('L',0),('R',.5)]:
            sole=min(clearance(points[i]) for i in soles[side])
            item['min_sole_clearance_m']=min(item['min_sole_clearance_m'],sole)
            if (phase+shift)%1<stance:
                item['max_support_clearance_m']=max(item['max_support_clearance_m'],abs(sole))
        count=crossings(points)
        max_crossings=max(max_crossings,count)
        item['crossings_by_frame'].append({'phase':phase,'edge_crossings':count})
    item['max_edge_crossings']=max_crossings
    item['worst_crossing_phases']=[r['phase'] for r in item['crossings_by_frame']
                                    if max_crossings and r['edge_crossings']==max_crossings]
    item['support_max_horizontal_drift_m']=max(r['world_horizontal_drift_m'] for r in item['support_segments'].values())
    item['flat_support_max_horizontal_drift_m']=max(r['world_horizontal_drift_m'] for k,r in item['support_segments'].items() if k.endswith('_flat'))
    report['clips'][name]=item
    print('CONTACT',name,json.dumps({k:v for k,v in item.items() if k not in ['support_segments','crossings_by_frame']}),flush=True)
(OUT/'contact_validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
for name,item in report['clips'].items():
    assert item['max_edge_crossings']==0, (name,'cloth crosses legs')
    assert item['flat_support_max_horizontal_drift_m']<.002, (name,'flat sole slides')
    assert item['min_sole_clearance_m']>-.005, (name,'sole penetrates floor')
print('CONTACT_VALIDATION_WRITTEN',flush=True)
