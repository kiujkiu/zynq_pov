"""anime_34.glb → anime_points.bin (16字节 PovPoint). 同 anime_to_bin.py, 仅换模型."""
import sys, struct
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import sample_glb

GLB = r"D:\workspace\zynq_pov\host\anime_34.glb"
OUT = r"D:\workspace\zynq_pov\anime_points.bin"
N_POINTS = int(sys.argv[1]) if len(sys.argv) > 1 else 100000

print(f"sampling {N_POINTS} pts on {GLB}...", flush=True)
# 面采样 (voxelize 被三角形数卡 ~22k, sample 能精确给 N). color_mode=keep 留纹理色.
pts = sample_glb(GLB, n_points=N_POINTS, target_scale=40, z_stretch=1.5, verbose=False,
                 color_mode="keep", brighten=1.5, gamma=0.9, saturation=2.0,
                 lighting="lambert", ambient=0.7)
print(f"  {len(pts)} points", flush=True)
with open(OUT, "wb") as f:
    for (x, y, z, r, g, b) in pts:
        x = max(-32768, min(32767, int(x))); y = max(-32768, min(32767, int(y))); z = max(-32768, min(32767, int(z)))
        r = max(0, min(255, int(r))); g = max(0, min(255, int(g))); b = max(0, min(255, int(b)))
        f.write(struct.pack("<4h4Bi", x, y, z, 0, r, g, b, 0, 0))
print(f"wrote {OUT}: {len(pts)*16} bytes ({len(pts)} points)", flush=True)
