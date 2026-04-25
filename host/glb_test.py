import sys
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import sample_glb
pts = sample_glb(r"D:\workspace\zynq_pov\host\anime_62459.glb", n_points=30, color_mode="keep", verbose=False)
print("color_mode=keep, first 15 points:")
for p in pts[:15]:
    print(" ", p)
# check variety
colors = set((p[3], p[4], p[5]) for p in pts)
print(f"unique colors: {len(colors)}")
for c in list(colors)[:20]:
    print(" ", c)
