"""Extract baseColorTexture from anime_62459_baked.glb and save as PNG.
Show raw texture vs baked texture side-by-side too.
"""
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.dirname(HERE)
sys.path.insert(0, PARENT)

import trimesh
import numpy as np
from PIL import Image

raw_glb = os.path.join(PARENT, "anime_62459.glb")
baked_glb = os.path.join(PARENT, "anime_62459_baked.glb")
out_dir = HERE

def extract_tex(glb_path, name):
    scene = trimesh.load(glb_path, process=False)
    geoms = list(scene.geometry.values()) if hasattr(scene, "geometry") else [scene]
    for i, mesh in enumerate(geoms):
        v = mesh.visual
        if hasattr(v, "material"):
            mat = v.material
            if hasattr(mat, "baseColorTexture") and mat.baseColorTexture is not None:
                tex = mat.baseColorTexture
                arr = np.array(tex)
                print(f"{name}[{i}]: tex {arr.shape} mode={tex.mode}")
                out = os.path.join(out_dir, f"tex_{name}_{i}.png")
                tex.save(out)
                print(f"  saved -> {out}")
                # stats
                if arr.ndim == 3:
                    rgb = arr[:, :, :3].reshape(-1, 3).astype(np.float32)
                    print(f"  R mean={rgb[:,0].mean():.1f} G={rgb[:,1].mean():.1f} B={rgb[:,2].mean():.1f}")
                    print(f"  R p95={np.percentile(rgb[:,0],95):.0f} G p95={np.percentile(rgb[:,1],95):.0f} B p95={np.percentile(rgb[:,2],95):.0f}")
                return tex
    return None

raw_tex = extract_tex(raw_glb, "raw")
baked_tex = extract_tex(baked_glb, "baked")

if raw_tex is not None and baked_tex is not None:
    # resize raw to match baked size for side-by-side
    target_size = baked_tex.size
    raw_resized = raw_tex.resize(target_size, Image.LANCZOS)
    side = Image.new("RGB", (target_size[0]*2 + 20, target_size[1]+30), (40,40,40))
    side.paste(raw_resized.convert("RGB"), (0, 30))
    side.paste(baked_tex.convert("RGB"), (target_size[0]+20, 30))
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(side)
    try:
        font = ImageFont.truetype("/mnt/c/Windows/Fonts/arial.ttf", 18)
    except Exception:
        font = ImageFont.load_default()
    draw.text((10, 6), "RAW TEX", fill=(220,220,220), font=font)
    draw.text((target_size[0]+30, 6), "BAKED TEX (warm 3-point + sunrise.exr)", fill=(220,220,220), font=font)
    out = os.path.join(out_dir, "tex_compare.png")
    side.save(out)
    print(f"saved -> {out}")
