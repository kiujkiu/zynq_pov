"""Dump color statistics for different modes to debug dimness."""
import sys
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import sample_glb

for mode in ["keep", "uniform", "height", "random"]:
    pts = sample_glb(r"D:\workspace\zynq_pov\host\anime_62459.glb",
                     n_points=200, color_mode=mode, brighten=1.0, verbose=False)
    r_avg = sum(p[3] for p in pts) / len(pts)
    g_avg = sum(p[4] for p in pts) / len(pts)
    b_avg = sum(p[5] for p in pts) / len(pts)
    max_r = max(p[3] for p in pts)
    max_g = max(p[4] for p in pts)
    max_b = max(p[5] for p in pts)
    print(f"[{mode}]  avg={r_avg:.0f},{g_avg:.0f},{b_avg:.0f}  max={max_r},{max_g},{max_b}")
