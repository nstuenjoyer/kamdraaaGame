"""Bake in-place locomotion on the protected-face rig; no external assets.

Run in background Blender with rig_v1/source/dasha_rig_v1.blend open.
Two-bone leg solving is baked into the existing 31-bone skeleton (no runtime IK).
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/characters/dasha_meshy/locomotion_v2'
for folder in (OUT, OUT/'source', OUT/'previews'):
    folder.mkdir(parents=True, exist_ok=True)
for folder in (OUT/'source', OUT/'previews'):
    (folder/'.gdignore').touch()
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in scene.objects if o.type == 'MESH' and o.parent == rig)
rig.animation_data_clear()
for action in list(bpy.data.actions):
    if action.users == 0: bpy.data.actions.remove(action)
rig.animation_data_create()
points = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
height = high.z-low.z
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
sys.path.insert(0, str(Path(__file__).parent))
from refine_dasha_skin import refine_skin, add_joint_support
from dasha_cloth_clearance import ClothClearance
skin = refine_skin(mesh, rig)
support = add_joint_support(mesh, skin['classification_ids'])
skin = refine_skin(mesh, rig)
cloth_solver = ClothClearance(mesh, rig, skin['classification_ids'])
(OUT/'skin_classification.json').write_text(json.dumps(skin['classification_ids']), encoding='utf-8')
scene.render.fps = 120

# Distances are metres per full left/right cycle; mirrored in dasha_animation.gd.
CLIPS = {
    'idle': dict(frames=120, distance=0, span=0, lift=0, crouch=0, lean=0),
    'walk': dict(frames=30, stance=.60, span=.34, lift=.045, crouch=.004, bob=.02, lean=2),
    'run': dict(frames=24, stance=.40, span=.44, lift=.13, crouch=.04, bob=.025, lean=9),
    'sneak': dict(frames=42, stance=.72, span=.20, lift=.035, crouch=.17, bob=.025, lean=7),
    'stairs_up': dict(frames=36, stance=.64, span=.22, lift=.17, crouch=.12, bob=.025, lean=6),
    'stairs_down': dict(frames=36, stance=.64, span=.22, lift=.10, crouch=.12, bob=.025, lean=-2),
}
for name, settings in CLIPS.items():
    if name != 'idle': settings['distance'] = 2*settings['span']/settings['stance']
    settings['frames'] *= 4
reach_errors = {name: [] for name in CLIPS}
contact_checks = {name: [] for name in CLIPS}
boot_points = {}
for side in ['L', 'R']:
    indices = [i for i in skin['classification_ids']['soles']+skin['classification_ids']['legs'] if
               (mesh.matrix_world @ mesh.data.vertices[i].co).z < low.z+height*.085 and
               any(mesh.vertex_groups[g.group].name == 'foot.'+side and g.weight>.999
                   for g in mesh.data.vertices[i].groups)]
    boot_points[side] = [mesh.matrix_world @ mesh.data.vertices[i].co for i in indices]


def smooth(t):
    t = max(0, min(1, t))
    return t*t*(3-2*t)


def hermite(a, b, velocity, u):
    return (2*u**3-3*u*u+1)*a+(-2*u**3+3*u*u)*b+(2*u**3-3*u*u+u)*velocity


def ankle_swing(name, u):
    # Positive roll points toes down. Initial swing follows the trailing shin,
    # then dorsiflexes for clearance; a single toe-off-to-landing lerp looked
    # like a gravity-stabilised boot while the knee bent underneath it.
    curves = {
        'walk': [(0,24),(.18,30),(.55,-6),(.85,-8),(1,-9)],
        'run': [(0,32),(.20,42),(.55,10),(.80,-8),(1,-12)],
        'sneak': [(0,10),(.18,15),(.55,-4),(.85,-5),(1,-5)],
        'stairs_up': [(0,22),(.18,30),(.55,-5),(.85,-8),(1,-9)],
        'stairs_down': [(0,18),(.18,25),(.55,-5),(.85,-8),(1,-9)]
    }
    keys = curves[name]
    for (a, start), (b, end) in zip(keys, keys[1:]):
        if u <= b: return start+(end-start)*smooth((u-a)/(b-a))
    return keys[-1][1]


def gait_sample(name, t):
    settings = CLIPS[name]
    stance = settings['stance']
    heel = 12 if name == 'run' else (5 if name == 'sneak' else 9)
    toe = ankle_swing(name, 0)
    if t < stance:
        return (settings['span']*(1-2*t/stance), 0,
                -heel*(1-smooth(t/.14))+toe*smooth((t-(stance-.16))/.16))
    u = (t-stance)/(1-stance)
    return (hermite(-settings['span'], settings['span'], -settings['distance']*(1-stance), u),
            settings['lift']*math.sin(math.pi*u)**1.5, ankle_swing(name, u))


def foot_target(side, forward, lift, roll, slope):
    ankle = rig.data.bones['foot.'+side].head_local.copy()
    base = Matrix.Rotation(-math.atan(slope), 3, 'X')
    rotation = Matrix.Rotation(math.radians(roll), 3, 'X') @ base
    offsets = [p-ankle for p in boot_points[side]]
    # Rotate about the lowest heel/toe point, compensating the entire sole.
    pivot = min(offsets, key=lambda p:(rotation@p).z+slope*(rotation@p).y)
    target = ankle.copy()
    target.y += -forward+(base@pivot).y-(rotation@pivot).y
    target.z = low.z-slope*(target.y-ankle.y)-min(
        (rotation@p).z+slope*(rotation@p).y for p in offsets)+lift
    return target, rotation, pivot


def reset():
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def rotate(name, x=0, y=0, z=0):
    from mathutils import Euler
    rig.pose.bones[name].rotation_quaternion = Euler(
        tuple(math.radians(a) for a in (x, y, z)), 'XYZ').to_quaternion()


def aim(name, head, tail):
    bone = rig.data.bones[name]
    q = (bone.tail_local-bone.head_local).rotation_difference(tail-head)
    rig.pose.bones[name].matrix = (Matrix.Translation(head) @ q.to_matrix().to_4x4()
                                  @ rest[name].to_quaternion().to_matrix().to_4x4())
    bpy.context.view_layer.update()


def leg(side, ankle, rotation, extension_limit=.995):
    requested = ankle.copy()
    thigh = rig.pose.bones['thigh.'+side]
    hip = thigh.head.copy()
    upper = rig.data.bones['thigh.'+side].length
    lower = rig.data.bones['shin.'+side].length
    offset = ankle-hip
    distance = min(offset.length, (upper+lower)*extension_limit)
    direction = offset.normalized()
    ankle = hip+direction*distance
    bend = Vector((0, -1, 0))
    bend = (bend-direction*bend.dot(direction)).normalized()
    along = (upper*upper-lower*lower+distance*distance)/(2*distance)
    knee = hip+direction*along+bend*math.sqrt(max(0, upper*upper-along*along))
    aim('thigh.'+side, hip, knee)
    aim('shin.'+side, knee, ankle)
    # Explicit ankle pitch, including trailing plantarflexion during swing.
    foot_matrix = (Matrix.Translation(ankle) @ rotation.to_4x4()
                   @ rest['foot.'+side].to_quaternion().to_matrix().to_4x4())
    rig.pose.bones['foot.'+side].matrix = foot_matrix
    bpy.context.view_layer.update()
    return (rig.pose.bones['foot.'+side].head-requested).length


def pose(name, phase):
    reset()
    settings = CLIPS[name]
    wave = math.sin(phase*math.tau)
    double = math.cos(phase*math.tau*2)
    if name == 'idle':
        rotate('spine', x=.55*wave)
        rotate('chest', x=-.35*wave, z=.25*wave)
        rotate('head', z=.5*math.sin(phase*math.tau))
        rotate('forearm.L', x=-3)
        rotate('forearm.R', x=-2)
        bpy.context.view_layer.update()
        return
    # Pelvis motion is deformation only; the CharacterBody owns translation/yaw.
    pelvis = rig.pose.bones['pelvis']
    bob = (-settings['bob']*math.cos((phase-.20)*math.tau*2) if name == 'run'
           else -settings['bob']*(.5+.5*double))
    pelvis.location = rest['pelvis'].to_3x3().inverted() @ Vector(
        (.012*wave, 0, -settings['crouch']+bob))
    rotate('pelvis', z=2.0*wave)
    rotate('spine', x=settings['lean']*.5, z=-1.2*wave)
    rotate('chest', x=settings['lean']*.5, z=-2*wave)
    rotate('neck', x=-settings['lean']*.3)
    rotate('head', x=-settings['lean']*.3)
    bpy.context.view_layer.update()
    # Preserve reachable planted targets at both feet instead of silently
    # shortening a leg and letting a boot float above its support plane.
    lower = 0
    for side, shift in [('L',0), ('R',.5)]:
        forward, lift, roll = gait_sample(name, (phase+shift) % 1)
        slope = (.45 if name == 'stairs_up' else -.45) if name.startswith('stairs') else 0
        target, _, _ = foot_target(side, forward, lift, roll, slope)
        hip = rig.pose.bones['thigh.'+side].head
        # Walking supports an upright body on a nearly extended leg. The old
        # reach margin plus a deep pelvis curve kept both knees crouched.
        reach_ratio = .997 if name == 'walk' else .99
        length = (rig.data.bones['thigh.'+side].length+rig.data.bones['shin.'+side].length)*reach_ratio
        horizontal = Vector((target.x-hip.x, target.y-hip.y, 0)).length
        allowed_height = math.sqrt(max(.01, length*length-horizontal*horizontal))
        lower = max(lower, hip.z-target.z-allowed_height)
    if lower > 0:
        pelvis.location += rest['pelvis'].to_3x3().inverted() @ Vector((0,0,-lower))
        bpy.context.view_layer.update()
    if name == 'walk':
        # Brief loading response after heel contact, followed by an extended
        # support leg. This is a small pulse, not a permanent crouching offset.
        loading = max((math.sin(math.pi*t/.20)**2 if t<.20 else 0)
                      for t in [phase % 1, (phase+.5) % 1]) * .006
        pelvis.location += rest['pelvis'].to_3x3().inverted() @ Vector((0,0,-loading))
        bpy.context.view_layer.update()
    for side, sign, shift in [('L',1,0), ('R',-1,.5)]:
        t = (phase+shift) % 1
        stance = settings['stance']
        forward, lift, roll = gait_sample(name, t)
        slope = (.45 if name == 'stairs_up' else -.45) if name.startswith('stairs') else 0
        ankle, rotation, pivot = foot_target(side, forward, lift, roll, slope)
        reach_errors[name].append(leg(side, ankle, rotation, .999 if name == 'walk' else .995))
        if t < stance:
            actual = rig.pose.bones['foot.'+side].matrix @ (rest['foot.'+side].inverted() @
                        (rig.data.bones['foot.'+side].head_local+pivot))
            # Forward world coordinate after adding linear root translation.
            contact_checks[name].append({'phase':phase, 'side':side,
                'world_forward':-actual.y+settings['distance']*phase,
                'clearance':actual.z-low.z+slope*(actual.y-rig.data.bones['foot.'+side].head_local.y)})
        swing = max(-1.15, min(1.15, forward/settings['span']))
        arm = 13 if name == 'walk' else (27 if name == 'run' else 5)
        rotate('upper_arm.'+side, x=arm*swing, z=sign*(2 if name == 'sneak' else 0))
        rotate('forearm.'+side, x=-(32 if name == 'run' else 8)-3*max(0,-swing))
        # Bag hand stays quieter than the free arm, with a delayed accessory swing.
        if side == 'R':
            rotate('upper_arm.R', x=arm*.35*swing)
        thigh = rig.pose.bones['thigh.'+side]
        vector = thigh.tail-thigh.head
        theta = math.degrees(math.atan2(-vector.y, -vector.z))
        for panel in ['front', 'back']:
            clearance = (-max(0,theta-3)*.70 if panel == 'front' else max(0,-theta-3)*.65)
            clearance = max(-32, min(28, clearance))
            rotate(f'coat_{panel}.{side}', x=clearance, z=sign*1.5)
            rotate(f'coat_{panel}.{side}_tip', x=clearance*.22+1.2*math.sin((phase+shift-.08)*math.tau))
    rotate('bag', x=3*math.sin((phase-.15)*math.tau), z=1.5*wave)
    bpy.context.view_layer.update()
    # Let the side seams open around a bent knee, rather than forcing the
    # entire front hem to rotate horizontally or clip through the trouser leg.
    spread = .03 if name == 'run' else .012
    for side, sign in [('L',1),('R',-1)]:
        for panel in ['front','back']:
            bone = rig.pose.bones[f'coat_{panel}.{side}']
            matrix = bone.matrix.copy()
            matrix.translation.x += spread*sign
            bone.matrix = matrix
    bpy.context.view_layer.update()


actions = {}
report = {'source': 'rig_v1/source/dasha_rig_v1.blend', 'bones':len(rig.data.bones),
          'geometry_changed':'planar support cuts on trousers only',
          'skin':{k:v for k,v in skin.items() if k!='classification_ids'},
          'joint_support':support, 'runtime_ik':False, 'clips':{}}
for name, settings in CLIPS.items():
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    scene.frame_start = 1
    scene.frame_end = settings['frames']+1
    offsets = []
    for frame in range(settings['frames']):
        pose(name, frame/settings['frames'])
        result = cloth_solver.required_offsets() if name != 'idle' else {
            'offsets':{'L':0,'R':0,'back.L':0,'back.R':0},'success':True}
        assert result['success'], (name,frame,result)
        offsets.append(result['offsets'])
    # A cyclic upper envelope smooths cloth corrections without averaging them
    # below the clearance required at a frame. No independent flapping sine.
    max_radius = round(scene.render.fps / 15)
    mean_radius = round(scene.render.fps / 30)
    smoothed = []
    for frame in range(settings['frames']):
        smoothed.append({side:sum(max(offsets[(frame+j+k)%len(offsets)][side]
            for k in range(-max_radius,max_radius+1))
            for j in range(-mean_radius,mean_radius+1))/(2*mean_radius+1) for side in offsets[0]})
    if name == 'run':
        # Reserve room for the interpolated pose between the 60 Hz source keys.
        smoothed = [{side:min(.24, amount+.01) if amount>0 else 0
                     for side,amount in sample.items()} for sample in smoothed]
    for frame in range(1, settings['frames']+2):
        scene.frame_set(frame)
        pose(name, (frame-1)/settings['frames'])
        cloth_solver.apply_offsets(smoothed[(frame-1)%len(smoothed)])
        for pb in rig.pose.bones:
            pb.keyframe_insert('location', frame=frame, group=pb.name)
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
    actions[name] = action
    report['clips'][name] = {'seconds':settings['frames']/scene.render.fps,
                             'cycle_distance':settings['distance'],
                             'front_coat_clearance_offset_max':max(max(v.values()) for v in smoothed),
                             'ankle_target_max_error':max(reach_errors[name], default=0)}
    assert max(reach_errors[name], default=0) < .015, (name, max(reach_errors[name]))
rig.animation_data.action = None
# Export one named strip per action, including on Blender versions using slots.
for name, action in actions.items():
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start = 1
    strip.action_frame_end = CLIPS[name]['frames']+1
    track.mute = True
rig.animation_data.action = actions['idle']
scene.frame_start = 1
scene.frame_end = CLIPS['idle']['frames']+1
scene.frame_set(1)
rig['animation_status'] = 'Refined gait: compensated heel/toe support, cloth weights and joint support'
mesh['rig_status'] = rig['animation_status']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/dasha_locomotion.blend'), compress=True)
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'dasha_locomotion.glb'), export_format='GLB',
    use_selection=True, export_yup=True, export_animations=True,
    export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False)
(OUT/'animation_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('ANIMATIONS_EXPORTED', json.dumps(report), flush=True)
if '--no-previews' in sys.argv:
    raise SystemExit(0)

# Review stills and short sequences, using the existing lit Blender scene.
scene.render.resolution_x = 320
scene.render.resolution_y = 400
scene.render.resolution_percentage = 100
if hasattr(scene, 'eevee'): scene.eevee.taa_render_samples = 24
center = (low+high)/2
camera = scene.camera
camera.data.ortho_scale = height*1.22
camera.location = center+Vector((1.5,-2.8,.6))*height
camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
for name in CLIPS:
    rig.animation_data.action = actions[name]
    scene.frame_set(1+round(CLIPS[name]['frames']*.25))
    scene.render.filepath = str(OUT/'previews'/f'{name}.png')
    bpy.ops.render.render(write_still=True)
for name in ['walk', 'run', 'sneak']:
    folder = OUT/'previews'/name
    folder.mkdir(exist_ok=True)
    rig.animation_data.action = actions[name]
    for index in range(24):
        frame = 1+index*CLIPS[name]['frames']/24
        scene.frame_set(int(frame), subframe=frame % 1)
        scene.render.filepath = str(folder/f'{index:03}.png')
        bpy.ops.render.render(write_still=True)
print('ANIMATION_PREVIEWS_COMPLETE', flush=True)
