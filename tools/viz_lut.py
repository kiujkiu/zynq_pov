"""Visualize calib_lut.json → scatter of all detected LED positions.

Color-codes each blob by its (chain, chip, bit) origin so you can eyeball:
  - whether the 9 chains form 3 expected row-bands × 3 colors
  - whether each chip → contiguous col group
  - whether each bit → consistent sub-position within chip

Run:
    python viz_lut.py [lut.json] [out.png]
"""
import sys, json, os
from PIL import Image, ImageDraw, ImageFont

LUT = sys.argv[1] if len(sys.argv) > 1 else r"D:\workspace\zynq_pov\tools\calib_out\calib_lut.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else r"D:\workspace\zynq_pov\tools\calib_out\lut_viz.png"

CANVAS_W, CANVAS_H = 1400, 1200
PAD = 40

lut = json.load(open(LUT))
print(f"loaded {len(lut)} tuples")

# Panel 0: scatter by chain — color per chain
img1 = Image.new("RGB", (CANVAS_W, CANVAS_H), "black")
d1 = ImageDraw.Draw(img1)
# Color per chain (9 chains): use HSV ring
import colorsys
chain_colors = [tuple(int(255*v) for v in colorsys.hsv_to_rgb(i/9, 1, 1)) for i in range(9)]

# Panel 1: per chip color
chip_colors = [tuple(int(255*v) for v in colorsys.hsv_to_rgb(i/12, 1, 1)) for i in range(12)]

# Panel 2: per bit color
bit_colors = [tuple(int(255*v) for v in colorsys.hsv_to_rgb(i/16, 1, 1)) for i in range(16)]

# 3 sub-panels stacked
SUB_W = CANVAS_W - 2*PAD
SUB_H = (CANVAS_H - 4*PAD) // 3

def draw_blobs(canvas, x_off, y_off, w, h, color_fn, title):
    d = ImageDraw.Draw(canvas)
    d.rectangle([x_off, y_off, x_off+w, y_off+h], outline="white", width=1)
    d.text((x_off+4, y_off+4), title, fill="white")
    for key, rec in lut.items():
        col = color_fn(rec)
        for bl in rec["blobs"]:
            x = x_off + int(bl["cx_pct"] / 100 * w)
            y = y_off + int(bl["cy_pct"] / 100 * h)
            d.ellipse([x-2, y-2, x+2, y+2], fill=col)

draw_blobs(img1, PAD, PAD,                 SUB_W, SUB_H, lambda r: chain_colors[r["chain"]], "by CHAIN (0..8)")
draw_blobs(img1, PAD, PAD*2 + SUB_H,       SUB_W, SUB_H, lambda r: chip_colors[r["chip"]],   "by CHIP (0..11)")
draw_blobs(img1, PAD, PAD*3 + SUB_H*2,     SUB_W, SUB_H, lambda r: bit_colors[r["bit"]],     "by BIT (0..15)")

img1.save(OUT)
print(f"saved {OUT}")

# Coverage stats
empty = [k for k,v in lut.items() if not v["blobs"]]
print(f"\ncoverage: {len(lut)-len(empty)}/{len(lut)} have blobs ({len(empty)} empty)")
if empty:
    print(f"first 20 empty keys: {empty[:20]}")
    # group by chain
    from collections import Counter
    by_chain = Counter(k.split('_')[0] for k in empty)
    print(f"empty per chain: {dict(by_chain)}")

# Range stats
xs = [bl["cx_pct"] for v in lut.values() for bl in v["blobs"]]
ys = [bl["cy_pct"] for v in lut.values() for bl in v["blobs"]]
if xs:
    print(f"x range: [{min(xs):.1f}, {max(xs):.1f}]%  y range: [{min(ys):.1f}, {max(ys):.1f}]%")
    print(f"total blobs: {len(xs)}, blobs/tuple avg = {len(xs)/len(lut):.2f}")
