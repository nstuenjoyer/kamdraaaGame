"""Import and preview the user's original Meshy asset without editing its mesh.

Run in a separate factory-startup background Blender; no live document touched.
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector

out=Path(r'E:\kamdraaa-game\assets\models\characters\dasha_meshy')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(out/'dasha_meshy.glb'))
imported=list(bpy.context.selected_objects)
meshes=[o for o in imported if o.type=='MESH']
model=bpy.data.collections.new('USER_MESHY_MODEL_ORIGINAL')
bpy.context.scene.collection.children.link(model)
for obj in imported:
    for col in list(obj.users_collection):col.objects.unlink(obj)
    model.objects.link(obj)
    obj['provenance']='User-supplied Meshy GLB; geometry and transforms preserved'
points=[o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
size=hi-lo;center=(hi+lo)/2
triangles=0
for obj in meshes:
    obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
textures=[]
for img in bpy.data.images:
    if img.type=='IMAGE' and img.source=='FILE':
        dimensions=list(img.size)  # Triggers loading of lazily decoded GLB images.
        img.pack();textures.append({'name':img.name,'size':dimensions})

scene=bpy.context.scene;scene.name='User_Meshy_Dasha_Inspection'
studio=bpy.data.collections.new('PREVIEW_STUDIO_NOT_PART_OF_MODEL')
scene.collection.children.link(studio)
def studio_link(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    studio.objects.link(obj)
height=size.z
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.085,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
bpy.ops.mesh.primitive_plane_add(size=height*200,location=(center.x,center.y,lo.z-height*.003))
floor=bpy.context.object;floor.name='Preview_floor';studio_link(floor)
mat=bpy.data.materials.new('Preview_ground');mat.use_nodes=True
bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.035,.043,.055,1)
bs.inputs['Roughness'].default_value=1
floor.data.materials.append(mat)
def light(name,offset,power,scale):
    data=bpy.data.lights.new(name,'AREA');data.energy=power*height*height;data.shape='DISK';data.size=scale*height
    obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=center+Vector(offset)*height
    obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-1.5,-2,2.3),110,1.8)
light('Fill',(1.8,-1,1.4),65,1.8)
light('Rim',(0,1.5,1.9),130,1.5)
data=bpy.data.cameras.new('Inspection_camera');camera=bpy.data.objects.new('Inspection_camera',data)
studio.objects.link(camera);scene.camera=camera
data.type='ORTHO';data.ortho_scale=height*1.18
def frame(offset):
    camera.location=center+Vector(offset)*height
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
frame((1.3,-2.8,.72))
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=850;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(out/'previews'/'three_quarter.png')
scene.unit_settings.system='METRIC'
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/'dasha_meshy_original.blend'),compress=True)
report={'source_filename':'Meshy_AI_Ashen_Sentinel_1102163907_texture.glb',
    'mesh_count':len(meshes),'triangles':triangles,'bounds_min':list(lo),'bounds_max':list(hi),
    'dimensions_blender_units':list(size),'textures':textures,
    'armatures':sum(o.type=='ARMATURE' for o in imported),'animations':len(bpy.data.actions),
    'geometry_modified':False,'transforms_modified':False}
(out/'inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('USER_MODEL_IMPORTED',json.dumps(report),flush=True)
for name,offset in [('three_quarter',(1.3,-2.8,.72)),('front',(0,-3,.35)),('back',(0,3,.35))]:
    frame(offset);scene.render.filepath=str(out/'previews'/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('PREVIEW_SAVED',name,flush=True)
