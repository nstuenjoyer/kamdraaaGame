"""Reproducible first PSX furniture kit. Run in an isolated background Blender.

Coordinates below are game X/Y/Z metres; Blender conversion is explicit.
Does not touch the user's live Blender document or character mesh.
"""
from pathlib import Path
import bpy
import math
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/environment/apartment_psx'
SOURCE = OUT / 'source'
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').touch()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
rng = random.Random(2117)


def texture(name, kind, n=128):
    image = bpy.data.images.new(name, width=n, height=n)
    pixels = []
    for y in range(n):
        for x in range(n):
            value = rng.uniform(.86, 1.0)
            if kind == 'wood':
                value *= .79 + .15 * math.sin(x * .42 + math.sin(y * .09) * 1.7)
                if x % 32 == 0:
                    value *= .60
            elif kind == 'cloth':
                value *= .86 if (x + y) % 3 == 0 else 1.0
                value *= .9 + .1 * math.sin(y * .08)
            pixels.extend((value, value, value, 1))
    image.pixels[:] = pixels
    image.pack()
    return image


wood_image = texture('WoodPainted128', 'wood')
cloth_image = texture('WovenCloth128', 'cloth')


def material(name, color, image=None, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = .95
    if image:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Closest'
        # glTF carries the base factor independently of its texture.
        mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
        shader.inputs['Base Color'].default_value = (*color, 1)
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = emission
    return mat


wood = material('DarkWalnut', (.22, .14, .085), wood_image)
trim = material('WornEdges', (.34, .23, .13), wood_image)
linen = material('AgedLinen', (.56, .51, .40), cloth_image)
blanket = material('SlateBlanket', (.20, .25, .26), cloth_image)
brass = material('TarnishedBrass', (.43, .30, .12))
black = material('Recesses', (.045, .04, .035))
shade = material('WarmLampshade', (.68, .46, .22), cloth_image)
glass = material('SmokedMirrorPlaceholder', (.19, .26, .28))


def empty(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


def cube(parent, name, p, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(p[0], -p[2], p[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Single angular chamfer', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def cylinder(parent, name, p, bottom, top, height, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=bottom, radius2=top,
                                  depth=height, location=(p[0], -p[2], p[1]))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


bed = empty('Bed')
cube(bed, 'Frame', (0, .28, 0), (2.1, .25, 2.9), wood, .035)
cube(bed, 'Mattress', (0, .52, 0), (2.03, .31, 2.80), linen, .09)
for x in (-1.02, 1.02):
    for z in (-1.40, 1.40):
        cube(bed, 'BedPost', (x, .48, z), (.13, .96, .13), trim, .02)
cube(bed, 'Headboard', (0, .92, -1.43), (2.15, .95, .12), wood, .035)
cube(bed, 'HeadboardRim', (0, 1.41, -1.43), (2.23, .10, .18), trim, .025)
cube(bed, 'FootRail', (0, .48, 1.43), (2.15, .20, .14), trim, .02)
for x in (-.53, .53):
    pillow = cube(bed, 'Pillow', (x, .77, -.94), (.88, .23, .56), linen, .10)
    pillow.rotation_euler.z = x * .13
# An irregular triangulated cover with deliberate broad folds.
verts, faces = [], []
nx, nz = 9, 8
for z in range(nz):
    for x in range(nx):
        gx = -1.04 + x / (nx - 1) * 2.08
        gz = -.55 + z / (nz - 1) * 1.97
        gy = .73 + .03 * math.sin(x * 1.6 + z * .8)
        if x in (0, nx - 1):
            gy -= .18
        if z == nz - 1:
            gy -= .19
        verts.append((gx, -gz, gy))
for z in range(nz - 1):
    for x in range(nx - 1):
        a = z * nx + x
        faces.extend(((a, a + nx, a + 1), (a + 1, a + nx, a + nx + 1)))
mesh = bpy.data.meshes.new('AngularBlanket')
mesh.from_pydata(verts, [], faces)
mesh.update()
cover = bpy.data.objects.new('FoldedCover', mesh)
bpy.context.collection.objects.link(cover)
cover.parent = bed
cover.data.materials.append(blanket)
uv = mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
    for loop_index in polygon.loop_indices:
        vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uv.data[loop_index].uv = ((vertex.x + 1.04) / 2.08, -vertex.y / 2)

nightstand = empty('Nightstand')
cube(nightstand, 'CabinetBody', (0, .43, 0), (.85, .78, .65), wood, .025)
cube(nightstand, 'OverhangingTop', (0, .86, 0), (.94, .08, .72), trim, .018)
for y in (.26, .60):
    cube(nightstand, 'DrawerInset', (0, y, .332), (.75, .28, .04), black)
    cube(nightstand, 'DrawerFace', (0, y, .36), (.70, .24, .04), trim, .012)
    cube(nightstand, 'DrawerPull', (0, y, .395), (.20, .04, .04), brass, .008)

lamp = empty('Lamp')
cylinder(lamp, 'LampFoot', (0, .02, 0), .16, .14, .04, brass)
cylinder(lamp, 'Stem', (0, .25, 0), .026, .026, .46, brass)
cylinder(lamp, 'Shade', (0, .51, 0), .26, .15, .32, shade)

chest = empty('Chest')
cube(chest, 'ChestBody', (0, .63, 0), (1.3, 1.26, .72), wood, .03)
cube(chest, 'ChestTop', (0, 1.30, 0), (1.42, .10, .81), trim, .025)
for y in (.27, .65, 1.03):
    cube(chest, 'DrawerInset', (0, y, .37), (1.20, .33, .035), black)
    cube(chest, 'DrawerFace', (0, y, .40), (1.13, .28, .035), trim, .012)
    for x in (-.35, .35):
        cube(chest, 'BrassPull', (x, y, .44), (.13, .035, .04), brass, .008)
cube(chest, 'MirrorFrame', (0, 2.15, -.27), (1.30, 1.55, .10), wood, .025)
cube(chest, 'MirrorGlass', (0, 2.15, -.205), (1.12, 1.35, .025), glass)

for obj in bpy.data.objects:
    if obj.type == 'MESH':
        obj.data.calc_loop_triangles()
        obj['triangle_count'] = len(obj.data.loop_triangles)
        obj['asset_stage'] = 'first furniture pass, not final approved art'

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'bedroom_kit.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'bedroom_kit.glb'), export_format='GLB',
                         export_animations=False, export_yup=True)
print('BEDROOM_KIT_EXPORTED', OUT)
