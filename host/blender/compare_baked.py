"""PIL software-render raw GLB vs Blender-baked GLB side-by-side.

Phase 9 task E: 验证 experiment/blender-bake-warm 改 (warm 3-point + sunrise.exr)
后 baked texture 颜色是否更暖、是否保留 anime 黑帽/白领 detail.

Usage (Win Python):
    python compare_baked.py [raw.glb] [baked.glb] [out.png]

Default:
    raw   = host/anime_62459.glb
    baked = host/anime_62459_baked.glb
    out   = host/blender/baked_vs_raw.png

Output PNG layout:
    +----------------------+----------------------+
    |     RAW (4 angles)   |    BAKED (4 angles)  |
    +----------------------+----------------------+
    上下两行 label
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.dirname(HERE)
sys.path.insert(0, PARENT)

from glb_to_mesh import build_simplified_mesh_per_tri

raw_glb = sys.argv[1] if len(sys.argv) > 1 else os.path.join(PARENT, "anime_62459.glb")
baked_glb = sys.argv[2] if len(sys.argv) > 2 else os.path.join(PARENT, "anime_62459_baked.glb")
out_png = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "baked_vs_raw.png")

TARGET_TRIS = 8000
W, H = 420, 540
SCALE = 4.6

def render_glb(glb_path, label, lighting=False):
    """Return one RGB strip with 4 angles.

    lighting=False: 直接看 baseColor — 区分 raw 原色 vs baked 暖光烤入.
    lighting=True : 走 host Option B 4-light IBL — 看板端真实显示效果.
    """
    print(f"[render] {label}: {glb_path}  lighting={lighting}")
    verts_xyz, tris = build_simplified_mesh_per_tri(
        glb_path, target_tris=TARGET_TRIS, target_scale=40, z_stretch=1.0,
        brighten=1.4 if lighting else 1.0,
        gamma=0.9 if lighting else 1.0,
        saturation=1.5 if lighting else 1.0,
        lighting=lighting, verbose=False)
    print(f"  mesh: {len(verts_xyz)} verts, {len(tris)} tris")
    verts = np.array(verts_xyz, dtype=np.float32)

    panels = []
    for ang_deg in (0, 90, 180, 270):
        c = math.cos(math.radians(ang_deg))
        s = math.sin(math.radians(ang_deg))
        rx = verts[:, 0] * c + verts[:, 2] * s
        rz = -verts[:, 0] * s + verts[:, 2] * c
        py = verts[:, 1]
        sx = (rx * SCALE + W / 2)
        sy = (H / 2 - py * SCALE)
        sz = rz
        img = Image.new("RGB", (W, H), (60, 60, 60))
        draw = ImageDraw.Draw(img)
        tri_z = []
        for i, (i0, i1, i2, r, g, b) in enumerate(tris):
            tz = (sz[i0] + sz[i1] + sz[i2]) / 3.0
            tri_z.append((tz, i))
        tri_z.sort(key=lambda x: x[0])
        for _, i in tri_z:
            i0, i1, i2, r, g, b = tris[i]
            pts = [(float(sx[i0]), float(sy[i0])),
                   (float(sx[i1]), float(sy[i1])),
                   (float(sx[i2]), float(sy[i2]))]
            draw.polygon(pts, fill=(int(r), int(g), int(b)))
        panels.append(np.array(img))
    return np.concatenate(panels, axis=1)


raw_strip = render_glb(raw_glb, "RAW", lighting=False)
baked_strip = render_glb(baked_glb, "BAKED", lighting=False)
baked_lit_strip = render_glb(baked_glb, "BAKED+OptB", lighting=True)

# 拼上下 3 行 + label
LABEL_H = 32
total_w = raw_strip.shape[1]
total_h = LABEL_H * 3 + raw_strip.shape[0] + baked_strip.shape[0] + baked_lit_strip.shape[0]
out = Image.new("RGB", (total_w, total_h), (30, 30, 30))
draw = ImageDraw.Draw(out)
try:
    font = ImageFont.truetype("/mnt/c/Windows/Fonts/arial.ttf", 18)
except Exception:
    font = ImageFont.load_default()

draw.text((10, 6), f"RAW (no lighting):   {os.path.basename(raw_glb)}",
          fill=(220, 220, 220), font=font)
out.paste(Image.fromarray(raw_strip), (0, LABEL_H))
y2 = LABEL_H + raw_strip.shape[0]
draw.text((10, y2 + 6), f"BAKED (no lighting): {os.path.basename(baked_glb)}  - shows pure baked baseColor",
          fill=(220, 220, 220), font=font)
out.paste(Image.fromarray(baked_strip), (0, y2 + LABEL_H))
y3 = y2 + LABEL_H + baked_strip.shape[0]
draw.text((10, y3 + 6), f"BAKED + Option B IBL (board path): brighten=1.4 gamma=0.9 sat=1.5",
          fill=(220, 220, 220), font=font)
out.paste(Image.fromarray(baked_lit_strip), (0, y3 + LABEL_H))

out.save(out_png)
print(f"saved -> {out_png}  ({out.size[0]}x{out.size[1]})")
