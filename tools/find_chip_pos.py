"""For each chipid snap, find the y-centroid of bright (>100) pixels.
Output gives chip→row position info."""
from PIL import Image
import os, sys

results = []
for i in range(1, 25):
    p = rf'D:\workspace\zynq_pov\tools\chipid_{i:02d}.jpg'
    try:
        im = Image.open(p).convert('L')
        w, h = im.size
        pix = im.load()
        ys, xs, count = 0, 0, 0
        for y in range(h):
            for x in range(w):
                v = pix[x, y]
                if v > 130:  # bright threshold
                    ys += y
                    xs += x
                    count += 1
        if count > 100:
            cy = ys / count
            cx = xs / count
            results.append((i, cy, cx, count, h))
            print(f"chipid_{i:02d}: y_center={cy:.0f} ({cy/h*100:.0f}%) x_center={cx:.0f} count={count}")
        else:
            print(f"chipid_{i:02d}: no bright pixels (mean too low)")
    except Exception as e:
        print(f"chipid_{i:02d}: error {e}")
