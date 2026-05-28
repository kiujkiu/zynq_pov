"""Compute brightness by 6 zones (TL/TM/TR/BL/BM/BR) for each verify snap."""
from PIL import Image
import os
out_dir = r"D:\workspace\zynq_pov\tools"
for i in range(1, 25):
    p = os.path.join(out_dir, f'verify_{i:02d}.jpg')
    im = Image.open(p).convert('L')
    w, h = im.size
    px = im.load()
    zones = {}
    layout = {
        'TL': (0, w//3, 0, h//2),
        'TM': (w//3, 2*w//3, 0, h//2),
        'TR': (2*w//3, w, 0, h//2),
        'BL': (0, w//3, h//2, h),
        'BM': (w//3, 2*w//3, h//2, h),
        'BR': (2*w//3, w, h//2, h),
    }
    for zname, (x0, x1, y0, y1) in layout.items():
        s = 0; n = 0
        for y in range(y0, y1, 4):
            for x in range(x0, x1, 4):
                s += px[x, y]; n += 1
        zones[zname] = s/n
    print(f"{i:02d}: TL={zones['TL']:5.0f} TM={zones['TM']:5.0f} TR={zones['TR']:5.0f}  BL={zones['BL']:5.0f} BM={zones['BM']:5.0f} BR={zones['BR']:5.0f}")
