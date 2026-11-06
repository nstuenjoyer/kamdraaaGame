"""Refine only the lower-body skin; preserve the protected source geometry.

Called by animate_dasha.py before action creation. The garment, trousers and
boots are separate components below the waist even though Meshy joined them
above it. Classification uses those components instead of an XY plane cut.
"""
from mathutils import Vector
from mathutils.kdtree import KDTree
import bmesh


def _smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def refine_skin(mesh, rig):
    """Replace coat/leg weights in place, returning reproducible diagnostics."""
    vertices = mesh.data.vertices
    world = [mesh.matrix_world @ v.co for v in vertices]
    lo = Vector(tuple(min(p[i] for p in world) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in world) for i in range(3)))
    height = hi.z-lo.z
    cx, cy = (lo.x+hi.x)/2, (lo.y+hi.y)/2
    points = [((p.x-cx)/height, (p.y-cy)/height, (p.z-lo.z)/height) for p in world]
    groups = {g.name:g for g in mesh.vertex_groups}
    group_names = {g.index:g.name for g in mesh.vertex_groups}
    original = [{group_names[g.group]:g.weight for g in v.groups} for v in vertices]
    bag_ids = {i for i,weights in enumerate(original) if weights.get('bag',0)>.5}
    adjacency = [[] for _ in vertices]
    for edge in mesh.data.edges:
        a,b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    remaining = {i for i,(_,_,z) in enumerate(points) if z<.53 and i not in bag_ids}
    components = []
    while remaining:
        start = min(remaining)
        remaining.remove(start)
        stack, ids = [start], []
        while stack:
            i = stack.pop()
            ids.append(i)
            for j in adjacency[i]:
                if j in remaining:
                    remaining.remove(j)
                    stack.append(j)
        components.append(ids)
    coat_ids, leg_ids, sole_ids = set(), set(), set()
    unknown = []
    for ids in components:
        ps = [points[i] for i in ids]
        xmin,xmax = min(p[0] for p in ps),max(p[0] for p in ps)
        zmin,zmax = min(p[2] for p in ps),max(p[2] for p in ps)
        if len(ids)>50 and xmin<-.08 and xmax>.08 and .24<zmin<.30:
            coat_ids.update(ids)
        elif len(ids)>50 and zmin<.04 and zmax>.15:
            leg_ids.update(ids)
        elif len(ids)>25 and zmax<.04:
            sole_ids.update(ids)
        else:
            unknown.append(ids)
    assert len(coat_ids)>300 and len(leg_ids)>400 and len(sole_ids)>150
    # Pant seams have disconnected duplicate geometry. Match them to the nearest
    # already classified surface. Hands/bag and upper torso remain unchanged.
    tree = KDTree(len(coat_ids | leg_ids))
    for i in sorted(coat_ids | leg_ids):
        tree.insert(Vector(points[i]),i)
    tree.balance()
    for ids in unknown:
        ps = [points[i] for i in ids]
        if any(abs(x)>.135 or z>.53 for x,y,z in ps):
            continue
        for i in ids:
            _, nearest, distance = tree.find(Vector(points[i]))
            if distance<.035:
                (coat_ids if nearest in coat_ids else leg_ids).add(i)

    changed = []
    def write(i, weights):
        weights = {name:w for name,w in weights.items() if w>1e-7}
        weights = dict(sorted(weights.items(),key=lambda item:(-item[1],item[0]))[:4])
        total = sum(weights.values())
        assert total>0
        for group in mesh.vertex_groups:
            group.remove([i])
        for name,weight in weights.items():
            groups[name].add([i],weight/total,'REPLACE')
        changed.append(i)

    for i in sorted(coat_ids):
        x,y,z = points[i]
        # Smooth seams between all four cloth quadrants; no knee/ankle binding.
        side = _smooth(-.025,.025,x)
        front = 1-_smooth(-.025,.025,y)
        base = _smooth(.30,.43,z)
        cloth = 1-_smooth(.46,.53,z)
        weights = {name:w*(1-cloth) for name,w in original[i].items()}
        for suffix,side_weight in [('L',side),('R',1-side)]:
            for panel,panel_weight in [('front',front),('back',1-front)]:
                prefix = 'coat_'+panel+'.'+suffix
                weight = cloth*side_weight*panel_weight
                weights[prefix] = weights.get(prefix,0)+weight*base
                weights[prefix+'_tip'] = weights.get(prefix+'_tip',0)+weight*(1-base)
        write(i,weights)

    for i in sorted(leg_ids | sole_ids):
        x,y,z = points[i]
        side = 'L' if x>=0 else 'R'
        if i in sole_ids or z<.085:
            weights = {'foot.'+side:1}
        elif z<.16:
            shin = _smooth(.085,.15,z)
            weights = {'foot.'+side:1-shin,'shin.'+side:shin}
        else:
            thigh = _smooth(.245,.335,z)
            weights = {'shin.'+side:1-thigh,'thigh.'+side:thigh}
        pelvis = _smooth(.43,.53,z)
        weights = {name:w*(1-pelvis) for name,w in weights.items()}
        weights['pelvis'] = pelvis
        write(i,weights)

    unchanged_ids = set(range(len(vertices)))-set(changed)
    assert all({group_names[g.group]:g.weight for g in vertices[i].groups}==original[i] for i in unchanged_ids)
    assert all(len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in vertices)
    assert all((mesh.matrix_world @ v.co-world[i]).length<1e-8 for i,v in enumerate(vertices))
    assert not (set(changed) & bag_ids)
    protected = {i for i,(_,_,z) in enumerate(points) if z>.815}
    assert not (set(changed) & protected)
    return {
        'method':'connected components below .53H; nearest surface for detached seams',
        'changed_vertices':len(changed), 'coat_vertices':len(coat_ids),
        'leg_vertices':len(leg_ids), 'sole_vertices':len(sole_ids),
        'protected_face_vertices':len(protected), 'bag_vertices_unchanged':len(bag_ids),
        'positions_uv_materials_unchanged':True, 'max_influences':4,
        'classification_ids':{'coat':sorted(coat_ids),'legs':sorted(leg_ids),'soles':sorted(sole_ids)}
    }


def add_joint_support(mesh, classification_ids):
    """Add planar support cuts to sparse trouser triangles, preserving silhouette.

    Original vertices, protected face polygons and their UVs are untouched.
    BMesh interpolates UV and deform layers at the new points. Call refine_skin
    again afterwards if fresh topological classification IDs are required.
    """
    before_vertices = len(mesh.data.vertices)
    before_polygons = len(mesh.data.polygons)
    world = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
    low = min(p.z for p in world)
    height = max(p.z for p in world)-low
    legs = set(classification_ids['legs'])
    protected = {i for i,p in enumerate(world) if (p.z-low)/height>.815}
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    originals = [(v,v.co.copy()) for v in bm.verts]
    uv_layers = list(bm.loops.layers.uv.values())
    protected_faces = []
    for face in bm.faces:
        if all(v.index in protected for v in face.verts):
            protected_faces.append((face, face.material_index, face.smooth,
                [[tuple(loop[layer].uv) for loop in face.loops] for layer in uv_layers]))
    selected = []
    for edge in bm.edges:
        a,b = edge.verts
        if a.index not in legs or b.index not in legs:
            continue
        za = (world[a.index].z-low)/height
        zb = (world[b.index].z-low)/height
        length = (world[a.index]-world[b.index]).length
        if .15<za<.48 and .15<zb<.48 and length>.10:
            selected.append(edge)
    assert selected, 'No trouser edges selected for support cuts'
    bmesh.ops.subdivide_edges(bm,edges=selected,cuts=2,smooth=0.0,use_grid_fill=True)
    bm.verts.ensure_lookup_table()
    position_tree = KDTree(len(bm.verts))
    for i,vertex in enumerate(bm.verts):
        position_tree.insert(vertex.co,i)
    position_tree.balance()
    original_error=0.0
    for vertex,position in originals:
        _, index, error = position_tree.find(position)
        original_error=max(original_error,error)
        assert error<1e-6, ('Original vertex lost during subdivision',error)
        # Some subdivision patterns replace endpoint elements. Match positions
        # rather than relying on BMesh element identity, then restore float ULPs.
        bm.verts[index].co=position
    for face,material,smooth,uv in protected_faces:
        assert face.is_valid and face.material_index==material and face.smooth==smooth
        assert uv==[[tuple(loop[layer].uv) for loop in face.loops] for layer in uv_layers]
    deform = bm.verts.layers.deform.active
    for vertex in bm.verts:
        weights = sorted(vertex[deform].items(),key=lambda item:(-item[1],item[0]))[:4]
        total = sum(w for _,w in weights)
        assert total>0
        vertex[deform].clear()
        for group,weight in weights:
            if weight/total>1e-7:
                vertex[deform][group]=weight/total
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    mesh.data.calc_loop_triangles()
    assert all(len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5
               for v in mesh.data.vertices)
    return {'selected_edges':len(selected), 'cuts_per_edge':2,
            'vertices_before':before_vertices,'vertices_after':len(mesh.data.vertices),
            'polygons_before':before_polygons,'polygons_after':len(mesh.data.polygons),
            'triangles_after':len(mesh.data.loop_triangles),
            'protected_vertices_unchanged':len(protected),
            'protected_polygons_and_uv_unchanged':len(protected_faces),
            'original_positions_unchanged':True,'subdivide_max_float_error':original_error,
            'smoothing':False}
