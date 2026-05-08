"""PIL ImageDraw 软渲染发到板子的 mesh, 4 个角度拼成 PNG.
绕开 3D viewer 的 vertex color 兼容性问题, 显示真实 per-tri color.

Output: host/sent_mesh_preview_render.png
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from glb_to_mesh import build_simplified_mesh_per_tri

target_tris = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
glb = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "anime_62459.glb")

verts_xyz, tris_with_color = build_simplified_mesh_per_tri(
    glb, target_tris=target_tris, target_scale=40, z_stretch=1.0,
    brighten=1.0, gamma=1.0, saturation=1.0,
    lighting=False, verbose=False)
print(f"mesh: {len(verts_xyz)} verts, {len(tris_with_color)} tris")

W, H = 360, 480
SCALE = 4.0           # model unit -> pixel
verts = np.array(verts_xyz, dtype=np.float32)

panels = []
for ang_deg in (0, 90, 180, 270):
    c = math.cos(math.radians(ang_deg))
    s = math.sin(math.radians(ang_deg))
    # 绕 y 轴旋转 (anime y-up). camera 看 -z 方向.
    rx = verts[:, 0] * c + verts[:, 2] * s
    rz = -verts[:, 0] * s + verts[:, 2] * c
    py = verts[:, 1]
    sx = (rx * SCALE + W / 2)
    sy = (H / 2 - py * SCALE)
    sz = rz   # depth (大 = 近)
    img = Image.new("RGB", (W, H), (80, 80, 80))
    draw = ImageDraw.Draw(img)
    # painter: sort tri by avg z (back to front)
    tri_z = []
    for i, (i0, i1, i2, r, g, b) in enumerate(tris_with_color):
        tz = (sz[i0] + sz[i1] + sz[i2]) / 3.0
        tri_z.append((tz, i))
    tri_z.sort(key=lambda x: x[0])  # ascending: 远先画
    for _, i in tri_z:
        i0, i1, i2, r, g, b = tris_with_color[i]
        pts = [(float(sx[i0]), float(sy[i0])),
               (float(sx[i1]), float(sy[i1])),
               (float(sx[i2]), float(sy[i2]))]
        draw.polygon(pts, fill=(int(r), int(g), int(b)))
    panels.append(np.array(img))
    print(f"  angle {ang_deg}° done")

strip = np.concatenate(panels, axis=1)
out_path = os.path.join(HERE, "sent_mesh_preview_render.png")
Image.fromarray(strip).save(out_path)
print(f"saved -> {out_path}  ({strip.shape[1]}x{strip.shape[0]})")
