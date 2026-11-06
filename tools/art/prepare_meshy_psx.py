"""Make a separate static PSX-style working copy of the user's Meshy asset.

Keep original mesh in its own hidden collection, preserve UV and transforms.
Run in factory-startup Blender against the inspected original .blend.
"""
import bpy
import bmesh
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

preserve_face='--preserve-face' in sys.argv
folder='psx_face_preserved' if preserve_face else 'psx_working'
out=Path(r'E:\kamdraaa-game\assets\models\characters\dasha_meshy')/folder
for directory in [out,out/'source',out/'previews']:directory.mkdir(parents=True,exist_ok=True)
for directory in [out/'source',out/'previews']:(directory/'.gdignore').touch()
scene=bpy.context.scene
original_collection=bpy.data.collections['USER_MESHY_MODEL_ORIGINAL']
original=next(o for o in original_collection.objects if o.type=='MESH')
original.data.calc_loop_triangles()
original_triangles=len(original.data.loop_triangles)
working=bpy.data.collections.new('DASHA_PSX_WORKING')
scene.collection.children.link(working)
obj=original.copy();obj.data=original.data.copy();obj.name='Dasha_PSX_Working'
working.objects.link(obj)
for o in original_collection.objects:o.hide_render=True;o.hide_set(True)
original_collection.hide_render=True
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
bpy.context.view_layer.objects.active=obj

points=[obj.matrix_world @ Vector(p) for p in obj.bound_box]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
height=hi.z-lo.z;center=(lo+hi)/2

# GLB splits positional vertices at UV/normal seams. Collapse on those splits
# creates tears, so weld coincident positions while keeping per-loop UV islands.
bm=bmesh.new();bm.from_mesh(obj.data)
before_weld={'vertices':len(bm.verts),'boundary_edges':sum(e.is_boundary for e in bm.edges)}
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=height*1e-6)
after_weld={'vertices':len(bm.verts),'boundary_edges':sum(e.is_boundary for e in bm.edges)}
bm.to_mesh(obj.data);bm.free();obj.data.update()

# Low collapse weights around face, hands and thin outer accessories.
vg=obj.vertex_groups.new(name='Simplification_influence')
bins={.18:[],.35:[],.65:[],1.0:[]}
if preserve_face:bins[0.0]=[]
locked_positions=[]
def face_lock(world):
    z=(world.z-lo.z)/height
    return z>.815 and abs(world.x-center.x)<height*.092 and world.y<center.y+height*.035
for v in obj.data.vertices:
    p=obj.matrix_world @ v.co
    z=(p.z-lo.z)/height;x=abs(p.x-center.x)
    if preserve_face and face_lock(p):
        weight=0.0;locked_positions.append(v.co.copy())
    elif z>.82 and x<height*.085:
        weight=.18 if p.y<center.y and .84<z<.98 else .35
    elif .40<z<.59 and x>height*.10:
        weight=.35
    elif x>height*.12 or z<.16:
        weight=.65
    else:weight=1.0
    bins[weight].append(v.index)
for weight,indices in bins.items():
    if indices:vg.add(indices,weight,'REPLACE')
protected_triangles=0
if preserve_face:
    locked_indices=set(bins[0.0])
    protected_triangles=sum(len(p.vertices)-2 for p in obj.data.polygons if all(i in locked_indices for i in p.vertices))
mod=obj.modifiers.new('Working_polygon_reduction','DECIMATE')
mod.decimate_type='COLLAPSE'
# The ratio counts the entire mesh. Reserve the original face plus a real body
# budget; asking for less than the protected head alone destroys the body.
mod.ratio=min(1,(protected_triangles+7450)/original_triangles) if preserve_face else .06
mod.use_collapse_triangulate=True
mod.vertex_group=vg.name;mod.vertex_group_factor=1.0
bpy.ops.object.modifier_apply(modifier=mod.name)
locked_report=None
if preserve_face:
    kd=KDTree(len(obj.data.vertices))
    for v in obj.data.vertices:kd.insert(v.co,v.index)
    kd.balance()
    errors=[kd.find(p)[2] for p in locked_positions]
    locked_report={'protected_vertices':len(locked_positions),'max_vertex_displacement':max(errors,default=0)}
    assert locked_report['max_vertex_displacement']<height*1e-6, locked_report
# Recalculate from surface faces instead of importing high-poly custom normals.
if obj.data.has_custom_normals:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
for polygon in obj.data.polygons:polygon.use_smooth=False
obj.data.update();obj.data.calc_loop_triangles()

# Keep only the diffuse painting for this style candidate, not the sculpt normal map.
original_mat=original.data.materials[0]
bs=original_mat.node_tree.nodes.get('Principled BSDF')
image_node=next(link.from_node for link in bs.inputs['Base Color'].links if link.from_node.type=='TEX_IMAGE')
base=image_node.image.copy();base.name='Dasha_PSX_Albedo_1024'
base.scale(1024,1024);base.pack()
base.filepath_raw=str(out/'dasha_albedo_1024.png');base.file_format='PNG';base.save()
mat=bpy.data.materials.new('Dasha_PSX_Painted_Matte');mat.use_nodes=True
shader=mat.node_tree.nodes['Principled BSDF']
shader.inputs['Roughness'].default_value=.9
shader.inputs['Metallic'].default_value=0
shader.inputs['Specular IOR Level'].default_value=0
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=base;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
obj.data.materials.clear();obj.data.materials.append(mat)
for p in obj.data.polygons:p.material_index=0
if preserve_face:
    # Preserve the source material throughout this likeness checkpoint. Mixing
    # source skin/PBR with a different cloth shader produced a visible neck seam.
    # Revisit texture/style reduction independently after facial likeness review.
    obj.data.materials.clear();obj.data.materials.append(original_mat)
    for polygon in obj.data.polygons:
        world_centre=obj.matrix_world @ polygon.center
        polygon.material_index=0
        if face_lock(world_centre):
            polygon.use_smooth=True
    obj.data.update()

# Quantify shape changes in local coordinates, rather than equating count with quality.
bvh=BVHTree.FromPolygons([tuple(v.co) for v in obj.data.vertices],
    [tuple(p.vertices) for p in obj.data.polygons])
distances=[];face_distances=[]
for i in range(0,len(original.data.vertices),20):
    p=original.data.vertices[i].co
    hit=bvh.find_nearest(p)
    if hit is None:continue
    distances.append(hit[3])
    world=original.matrix_world @ p
    if (world.z-lo.z)/height>.82 and abs(world.x-center.x)<height*.085:
        face_distances.append(hit[3])
def stats(values):
    values=sorted(values)
    return {'samples':len(values),'max':max(values,default=0),
        'p95':values[min(len(values)-1,int(len(values)*.95))] if values else 0}

obj['status']='Static style working copy; requires approval, rig and deformation topology work'
obj['source_triangles']=original_triangles
obj['source_file']='dasha_meshy.glb'
scene['status']='User Meshy asset: reduced geometry and matte pixel-texture working candidate'
scene.render.filepath=str(out/'previews'/'three_quarter.png')
camera=scene.camera
def frame(offset,target=center,scale=height*1.18):
    camera.data.ortho_scale=scale
    camera.location=target+Vector(offset)*height
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
frame((1.3,-2.8,.72))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/'dasha_psx_working.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(out/'dasha_psx_working.glb'),export_format='GLB',
    use_selection=True,export_yup=True,export_animations=False)
report={'original_triangles':original_triangles,'working_triangles':len(obj.data.loop_triangles),
    'reduction_percent':round(100*(1-len(obj.data.loop_triangles)/original_triangles),2),
    'vertices':len(obj.data.vertices),'texture_size':list(image_node.image.size) if preserve_face else list(base.size),
    'uv_layers':len(obj.data.uv_layers),'flat_shaded':'body only' if preserve_face else True,'rigged':False,
    'normal_map_used':'original material throughout' if preserve_face else False,'transforms_preserved':True,
    'face_locked':locked_report,'facial_material_preserved':preserve_face,
    'protected_source_triangles':protected_triangles,
    'before_weld':before_weld,'after_weld':after_weld,
    'sampled_surface_distance_local_units':stats(distances),
    'sampled_head_distance_local_units':stats(face_distances),
    'status':'Unapproved static style copy; decimation is not animation retopology'}
(out/'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WORKING_COPY_SAVED',json.dumps(report),flush=True)
for name,offset in [('three_quarter',(1.3,-2.8,.72)),('front',(0,-3,.35)),('back',(0,3,.35))]:
    frame(offset);scene.render.filepath=str(out/'previews'/(name+'.png'))
    bpy.ops.render.render(write_still=True)
face_target=Vector((center.x,center.y,lo.z+height*.90))
frame((1.3,-2.8,.35),target=face_target,scale=height*.36)
scene.render.filepath=str(out/'previews'/'head_closeup.png');bpy.ops.render.render(write_still=True)
if preserve_face:
    obj.hide_render=True;original_collection.hide_render=False
    for o in original_collection.objects:o.hide_render=False
    scene.render.filepath=str(out/'previews'/'original_head_same_camera.png')
    bpy.ops.render.render(write_still=True)
print('PSX_PREVIEWS_COMPLETE',flush=True)
