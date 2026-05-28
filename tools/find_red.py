"""Find horizontal position of bright red region in each chip snap."""
from PIL import Image
import os
for i in range(1, 17):
    p = rf'D:\workspace\zynq_pov\tools\chip2_{i:02d}.jpg'
    im = Image.open(p).convert('RGB')
    w, h = im.size
    # bottom 30% of image (panel area)
    r_data = []
    for y in range(int(h*0.65), h):
        for x in range(w):
            r, g, b = im.getpixel((x, y))
            if r > g + 40 and r > b + 40 and r > 120:
                r_data.append(x)
    if r_data:
        cx = sum(r_data) / len(r_data)
        mn = min(r_data)
        mx = max(r_data)
        print(f"chip2_{i:02d}: red_x mean={cx:.0f} ({cx/w*100:.0f}%) range=[{mn},{mx}] count={len(r_data)}")
    else:
        print(f"chip2_{i:02d}: no clear red region")
