"""For each calib snap, find centroid of bright red region (chain 0 = red)."""
from PIL import Image
import os
out_dir = r"D:\workspace\zynq_pov\tools"

print(f"{'snap':4s} {'cx%':>5s} {'cy%':>5s} {'count':>7s} {'mean_r':>7s}")
results = []
for i in range(1, 51):
    p = os.path.join(out_dir, f'calib_{i:02d}.jpg')
    im = Image.open(p).convert('RGB')
    w, h = im.size
    px = im.load()
    # Crop to panel area: right ~70% of image, full height (based on prior snaps)
    x0, x1 = int(w*0.30), w
    y0, y1 = 0, h
    sx, sy, cnt, r_total = 0, 0, 0, 0
    for y in range(y0, y1, 2):
        for x in range(x0, x1, 2):
            r, g, b = px[x, y]
            # red dominant (LED is red)
            if r > 130 and r > g + 30 and r > b + 30:
                sx += x; sy += y; cnt += 1; r_total += r
    if cnt > 30:
        cx_pct = (sx/cnt - x0) / (x1-x0) * 100
        cy_pct = (sy/cnt) / h * 100
        print(f"{i:4d} {cx_pct:5.0f} {cy_pct:5.0f} {cnt:7d} {r_total/cnt:7.0f}")
        results.append((i, cx_pct, cy_pct, cnt))
    else:
        print(f"{i:4d}    -    -       -       -")
