"""Inspect mesh stats."""
from glb_to_mesh import build_simplified_mesh

verts, faces = build_simplified_mesh('anime_62459.glb', target_tris=4096,
                                      target_scale=40, z_stretch=1.5,
                                      brighten=1.5, gamma=0.85, saturation=1.5,
                                      verbose=False)
print(f'verts={len(verts)}  faces={len(faces)}')
xs = [v[0] for v in verts]
ys = [v[1] for v in verts]
zs = [v[2] for v in verts]
print(f'x range: [{min(xs)}..{max(xs)}]  span={max(xs)-min(xs)}')
print(f'y range: [{min(ys)}..{max(ys)}]  span={max(ys)-min(ys)}')
print(f'z range: [{min(zs)}..{max(zs)}]  span={max(zs)-min(zs)}')
xm = sum(xs) / len(xs)
ym = sum(ys) / len(ys)
print(f'centroid: x={xm:.1f}  y={ym:.1f}')

# Triangle area distribution after projection
import math
tri_areas = []
for (i0, i1, i2) in faces:
    v0 = verts[i0]; v1 = verts[i1]; v2 = verts[i2]
    a2 = (v1[0]-v0[0])*(v2[1]-v0[1]) - (v1[1]-v0[1])*(v2[0]-v0[0])
    tri_areas.append(abs(a2)/2)
zeros = sum(1 for a in tri_areas if a == 0)
print(f'all {len(tri_areas)} tri 2D xy area: min={min(tri_areas):.1f} max={max(tri_areas):.1f} mean={sum(tri_areas)/len(tri_areas):.1f}')
print(f'  area == 0: {zeros} / {len(tri_areas)} ({100*zeros/len(tri_areas):.0f}%)')
import numpy as np
ar_np = np.array(tri_areas)
print(f'  median={np.median(ar_np):.1f}  90%-ile={np.percentile(ar_np, 90):.1f}')
