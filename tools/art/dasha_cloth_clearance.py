"""Offline four-panel clearance fitting on the current skinned pose.

Trials use the exact linear translation contribution of each garment panel and
its child tip, measured from the current evaluated mesh. This avoids changing
the rig repeatedly during the search; required_offsets() leaves the pose alone.
"""
import bpy
import math
from mathutils import Vector
from mathutils.bvhtree import BVHTree


class ClothClearance:
    def __init__(self, mesh, rig, classification_ids, cap=.24, margin=.006):
        self.mesh, self.rig = mesh, rig
        self.cap, self.margin = cap, margin
        self.world_forward = Vector((0,-1,0))
        self.controls = {'L':('coat_front.L',-1,'L_front'),
                         'R':('coat_front.R',-1,'R_front'),
                         'back.L':('coat_back.L',1,'L_back'),
                         'back.R':('coat_back.R',1,'R_back')}
        base = [mesh.matrix_world@v.co for v in mesh.data.vertices]
        lo = min(p.z for p in base)
        height = max(p.z for p in base)-lo
        coat, legs = set(classification_ids['coat']),set(classification_ids['legs'])
        mesh.data.calc_loop_triangles()
        triangles = [tuple(t.vertices) for t in mesh.data.loop_triangles if
            all(i in coat and (base[i].z-lo)/height<.43 for i in t.vertices)]
        self.cloth_ids = sorted({i for t in triangles for i in t})
        remap = {i:j for j,i in enumerate(self.cloth_ids)}
        self.triangles = [tuple(remap[i] for i in t) for t in triangles]
        self.triangle_panels = []
        for triangle in triangles:
            center = sum((base[i] for i in triangle),Vector())/3
            self.triangle_panels.append(('L' if center.x>0 else 'R')+
                ('_front' if center.y<0 else '_back'))
        self.edges = [tuple(e.vertices) for e in mesh.data.edges if
            all(i in legs and .20<(base[i].z-lo)/height<.43 for i in e.vertices)]
        self.leg_ids = sorted({i for e in self.edges for i in e})
        names = {g.index:g.name for g in mesh.vertex_groups}
        self.contributions = {}
        for i in self.cloth_ids:
            contribution = {name:0 for name in self.controls}
            for group in mesh.data.vertices[i].groups:
                name = names[group.group]
                for control,(bone,sign,panel) in self.controls.items():
                    if name in [bone,bone+'_tip']:
                        contribution[control] += group.weight
            self.contributions[i] = contribution
        # The leg mesh must not follow garment-panel translations.
        for i in self.leg_ids:
            assert all(not names[g.group].startswith('coat_') or g.weight<1e-6
                       for g in mesh.data.vertices[i].groups)
        modifiers = [m for m in mesh.modifiers if m.type=='ARMATURE' and m.object==rig]
        assert len(modifiers)==1 and not modifiers[0].use_deform_preserve_volume
        assert len(self.triangles)>40 and len(self.edges)>40

    def _capture(self):
        bpy.context.view_layer.update()
        evaluated = self.mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        geometry = evaluated.to_mesh()
        ids = set(self.cloth_ids)|set(self.leg_ids)
        points = {i:evaluated.matrix_world@geometry.vertices[i].co for i in ids}
        evaluated.to_mesh_clear()
        return points

    def _crossings(self, points, offsets):
        cloth = []
        for i in self.cloth_ids:
            weights = self.contributions[i]
            shift = sum(weights[name]*offsets.get(name,0)*sign
                        for name,(bone,sign,panel) in self.controls.items())
            cloth.append(points[i]+Vector((0,shift,0)))
        tree = BVHTree.FromPolygons(cloth,self.triangles,all_triangles=True,epsilon=0)
        counts = {'total':0,'L_front':0,'R_front':0,'L_back':0,'R_back':0}
        for a,b in self.edges:
            offset = points[b]-points[a]
            length = offset.length
            if length<1e-5:continue
            direction = offset/length
            location,normal,index,distance = tree.ray_cast(
                points[a]+direction*1e-5,direction,length-2e-5)
            if location is not None and distance>1e-5 and abs(normal.dot(direction))>.05:
                counts['total'] += 1
                counts[self.triangle_panels[index]] += 1
        return counts

    def required_offsets(self):
        """Return minimum sampled outward shifts and truthful residual counts.

        No pose properties are changed. The 6 mm margin is extra outward travel
        after clearing intersections, not a claim of closest-surface distance.
        """
        points = self._capture()
        offsets = {name:0.0 for name in self.controls}
        before = self._crossings(points,offsets)
        counts = before
        margin_truncated = False
        for _ in range(5):
            changed = False
            for side in ['R','L','back.R','back.L']:
                panel = self.controls[side][2]
                if counts[panel]==0:continue
                original = offsets[side]
                last_bad = original
                found = None
                for step in range(1,math.ceil((self.cap-original)/.01)+1):
                    candidate = min(self.cap,original+step*.01)
                    trial = dict(offsets);trial[side] = candidate
                    trial_counts = self._crossings(points,trial)
                    if trial_counts[panel]==0:
                        found=candidate
                        break
                    last_bad=candidate
                if found is None:
                    offsets[side]=self.cap
                else:
                    for _ in range(7):
                        midpoint=(last_bad+found)/2
                        trial=dict(offsets);trial[side]=midpoint
                        if self._crossings(points,trial)[panel]==0:
                            found=midpoint
                        else:last_bad=midpoint
                    margin_truncated |= found+self.margin>self.cap
                    offsets[side]=min(self.cap,found+self.margin)
                counts=self._crossings(points,offsets)
                changed |= offsets[side]>original+1e-6
            if counts['total']==0 or not changed:break
        counts=self._crossings(points,offsets)
        return {'offsets':offsets,'before':before,'after':counts,
                'success':counts['total']==0,'cap_m':self.cap,
                'forward_margin_m':self.margin,'margin_truncated':margin_truncated,
                'cap_exceeded':counts['total']>0 and any(v>=self.cap-1e-6 for v in offsets.values())}

    def apply_offsets(self, offsets):
        """Apply outward world-Y deltas to the four roots, preserving rotation."""
        bpy.context.view_layer.update()
        inverse = self.rig.matrix_world.inverted().to_3x3()
        for side,(name,sign,panel) in self.controls.items():
            amount = float(offsets.get(side,0))
            if not amount:continue
            bone = self.rig.pose.bones[name]
            matrix = bone.matrix.copy()
            matrix.translation += inverse@Vector((0,sign*amount,0))
            bone.matrix = matrix
        bpy.context.view_layer.update()
