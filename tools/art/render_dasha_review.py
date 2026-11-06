"""Render a selected locomotion_v2 clip from an audit angle; never save model.

Background Blender: --python tools/art/render_dasha_review.py --
    --clip walk --view side [--in-place] [--output path]

Default review adds the authored forward translation while the camera stays
fixed. This reveals planted-foot sliding hidden by in-place turntable previews.
"""
import bpy
import sys
import json
import argparse
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2/source/dasha_locomotion.blend'
parser = argparse.ArgumentParser()
parser.add_argument('--clip', default='walk', choices=['idle','walk','run','sneak','stairs_up','stairs_down'])
parser.add_argument('--view', default='side', choices=['side','back_three_quarter','front_three_quarter'])
parser.add_argument('--in-place', action='store_true')
parser.add_argument('--output', type=Path)
parser.add_argument('--phase', type=float, help='Render one inspection still at this phase instead of a sequence')
parser.add_argument('--width', type=int, default=320)
parser.add_argument('--height', type=int, default=400)
parser.add_argument('--frames', type=int, default=24, help='Number of samples over one full cycle')
parser.add_argument('--lower-body', action='store_true', help='Fit feet, ankles and knees below 0.45 of bind height')
parser.add_argument('--resume', action='store_true', help='Keep existing PNG samples while completing an interrupted render')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert 1 <= args.frames <= 240, args.frames
assert SOURCE.is_file(), SOURCE
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in scene.objects if o.type == 'MESH' and o.parent == rig)
action = bpy.data.actions.get(args.clip)
assert action is not None, (args.clip, list(bpy.data.actions.keys()))
manifest = json.loads((SOURCE.parent.parent/'animation_report.json').read_text(encoding='utf-8'))
distance = manifest['clips'][args.clip]['cycle_distance']
rig.animation_data_create()
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = action
rig.animation_data.action_slot = action.slots[0]
start, end = action.frame_range
points = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
height = high.z-low.z
fit_indices = [i for i,p in enumerate(points) if p.z < low.z+.45*height] if args.lower_body else []
if args.lower_body:
    assert fit_indices
    selected = [points[i] for i in fit_indices]
    low_fit = Vector(tuple(min(p[i] for p in selected) for i in range(3)))
    high_fit = Vector(tuple(max(p[i] for p in selected) for i in range(3)))
    center = (low_fit+high_fit)/2
else:
    center = (high+low)/2
if not args.in_place:
    center += Vector((0,-distance*(.5 if args.phase is None else args.phase),0))
offsets = {'side':(3.0,0,.35), 'back_three_quarter':(1.8,2.8,.45),
           'front_three_quarter':(1.8,-2.8,.45)}
camera = scene.camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = max(height*1.25, (distance+.6)/(args.width/args.height) if not args.in_place and args.phase is None else 0)
camera.location = center+Vector(offsets[args.view])*height
camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x = args.width
scene.render.resolution_y = args.height
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
if hasattr(scene, 'eevee'):
    scene.eevee.taa_render_samples = 24
output = args.output or ROOT/'.godot/dasha-motion-review/blender'/f'{args.clip}_{args.view}'
output.mkdir(parents=True, exist_ok=True)
initial_location = rig.location.copy()
phases = [args.phase] if args.phase is not None else [i/args.frames for i in range(args.frames)]
# Fit the entire deformed silhouette/travel, not just the bind-pose body. A
# contact pose extends one boot behind the initial root position.
camera_axes = camera.rotation_euler.to_matrix()
right, up = camera_axes.col[0], camera_axes.col[1]
extent_x = extent_y = 0.0
for phase in phases:
    frame = start+(end-start)*phase
    scene.frame_set(int(frame), subframe=frame % 1)
    translation = Vector((0,-distance*phase,0)) if not args.in_place else Vector()
    if args.clip.startswith('stairs') and not args.in_place:
        translation.z = distance*phase*(.45 if args.clip == 'stairs_up' else -.45)
    rig.location = initial_location+translation
    bpy.context.view_layer.update()
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    fitted_mesh = evaluated.to_mesh() if args.lower_body else None
    fit_points = (fitted_mesh.vertices[i].co for i in fit_indices) if args.lower_body else evaluated.bound_box
    for corner in fit_points:
        offset = evaluated.matrix_world @ Vector(corner)-center
        extent_x = max(extent_x,abs(offset.dot(right)))
        extent_y = max(extent_y,abs(offset.dot(up)))
    if fitted_mesh is not None: evaluated.to_mesh_clear()
camera.data.ortho_scale = max(extent_y,extent_x/(args.width/args.height))*2.12
frames = []
try:
    for index, phase in enumerate(phases):
        frame = start+(end-start)*phase
        scene.frame_set(int(frame), subframe=frame % 1)
        translation = Vector((0,-distance*phase,0)) if not args.in_place else Vector()
        if args.clip.startswith('stairs') and not args.in_place:
            translation.z = distance*phase*(.45 if args.clip == 'stairs_up' else -.45)
        rig.location = initial_location+translation
        bpy.context.view_layer.update()
        scene.render.filepath = str(output/f'{index:03}.png')
        if not args.resume or not Path(scene.render.filepath).is_file():
            bpy.ops.render.render(write_still=True)
        frames.append({'index':index, 'phase':phase, 'root_translation':list(translation)})
finally:
    rig.location = initial_location
report = {'source':str(SOURCE), 'clip':args.clip, 'view':args.view, 'in_place':args.in_place,
          'lower_body':args.lower_body,
          'seconds':manifest['clips'][args.clip]['seconds'], 'size':[args.width,args.height], 'frames':frames}
(output/'capture.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('DASHA_BLENDER_REVIEW',str(output),flush=True)
