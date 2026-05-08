"""Median-filter the baked texture inside anime_62459_baked.glb, save as
anime_62459_baked_clean.glb. 用 trimesh 重打包 GLB.
"""
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.dirname(HERE)
sys.path.insert(0, PARENT)

import trimesh
from PIL import Image, ImageFilter

IN_GLB = os.path.join(PARENT, "anime_62459_baked.glb")
OUT_GLB = os.path.join(PARENT, "anime_62459_baked_clean.glb")

scene = trimesh.load(IN_GLB, process=False)
print(f"loaded: {type(scene).__name__}")
if hasattr(scene, "geometry"):
    geoms = list(scene.geometry.values())
else:
    geoms = [scene]
print(f"geometries: {len(geoms)}")

for i, mesh in enumerate(geoms):
    visual = mesh.visual
    print(f"  geom[{i}] visual={type(visual).__name__}")
    if hasattr(visual, "material") and hasattr(visual.material, "baseColorTexture"):
        tex = visual.material.baseColorTexture
        if tex is not None:
            print(f"    base tex: {tex.size} {tex.mode}")
            cleaned = tex.filter(ImageFilter.MedianFilter(size=5))
            cleaned = cleaned.filter(ImageFilter.GaussianBlur(radius=1.5))
            visual.material.baseColorTexture = cleaned
            print(f"    cleaned (median 5 + blur 1.5)")

if hasattr(scene, "geometry"):
    scene.export(OUT_GLB)
else:
    geoms[0].export(OUT_GLB)
print(f"saved -> {OUT_GLB}")
