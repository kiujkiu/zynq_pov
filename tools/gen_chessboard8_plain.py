"""128x128 8x8 chessboard, 16x16 cells, SOLID colors no digits."""
import os, sys, colorsys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
img = Image.new('RGB', (128, 128), (0, 0, 0))
draw = ImageDraw.Draw(img)
CELL = 16

def cell_color(idx):
    # 64 distinct HSV colors at full brightness (V=1.0 = RGB 255 = all BCM bits set)
    h = (idx % 64) / 64.0
    r, g, b = colorsys.hsv_to_rgb(h, 1.0, 1.0)
    return (int(r*255), int(g*255), int(b*255))

for row in range(8):
    for col in range(8):
        idx = row * 8 + col
        x0 = col * CELL
        y0 = row * CELL
        draw.rectangle((x0, y0, x0+CELL-1, y0+CELL-1), fill=cell_color(idx))

img.save(os.path.join(OUT_DIR, 'test_chess8_plain.png'))
write_panels(img, OUT_DIR)
print("8x8 plain chessboard written")
